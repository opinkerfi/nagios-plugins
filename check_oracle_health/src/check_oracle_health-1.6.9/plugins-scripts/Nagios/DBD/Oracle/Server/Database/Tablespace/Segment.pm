package DBD::Oracle::Server::Database::Tablespace::Segment;

use strict;

our @ISA = qw(DBD::Oracle::Server::Database::Tablespace);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  my @segments = ();
  my $initerrors = undef;

  sub add_segment {
    push(@segments, shift);
  }

  sub return_segments {
    return reverse
        sort { $a->{name} cmp $b->{name} } @segments;
  }

  sub clear_segments {
    @segments = ();
  }

  sub init_segments {
    my %params = @_;
    my $num_segments = 0;
    if (($params{mode} =~
        /server::database::tablespace::segment::top10logicalreads/) ||
        ($params{mode} =~
        /server::database::tablespace::segment::top10physicalreads/) ||
        ($params{mode} =~
        /server::database::tablespace::segment::top10bufferbusywaits/) ||
        ($params{mode} =~
        /server::database::tablespace::segment::top10rowlockwaits/)) {
      my %thisparams = %params;
      $thisparams{name} = "dummy_segment";
      my $segment = DBD::Oracle::Server::Database::Tablespace::Segment->new(
          %thisparams);
      add_segment($segment);
      $num_segments++;
    } elsif ($params{mode} =~
        /server::database::tablespace::segment::extendspace/) {
      my @tablespaceresult = $params{handle}->fetchall_array(q{
          SELECT /*+ RULE */
              -- tablespace, segment, extent
              -- aber dadurch, dass nur das letzte extent selektiert wird
              -- werden praktisch nur tablespace und segmente ausgegeben
              b.tablespace_name "Tablespace",
              b.segment_type "Type",
              SUBSTR(ext.owner||'.'||ext.segment_name,1,50) "Object Name",
              DECODE(freespace.extent_management, 
                'DICTIONARY', DECODE(b.extents, 
                  1, b.next_extent, ext.bytes * (1 + b.pct_increase / 100)),
                  'LOCAL', DECODE(freespace.allocation_type,
                    'UNIFORM', freespace.initial_extent,
                    'SYSTEM', ext.bytes)
              ) "Required Extent",
              freespace.largest "MaxAvail"
          FROM
              -- dba_segments b,
              -- dba_extents ext,
              (
                SELECT
                    owner, segment_type, segment_name, extents, pct_increase,
                    next_extent, tablespace_name
                FROM
                    dba_segments
                WHERE
                    tablespace_name = ?
              ) b,
              (
                SELECT
                    owner, segment_type, segment_name, extent_id, bytes,
                    tablespace_name
                FROM
                    dba_extents
                WHERE
                    tablespace_name = ?
              ) ext,
              (
                -- dictionary/local, uniform/system, initial, next
                -- und der groesste freie extent pro tablespace
                SELECT
                    b.tablespace_name,
                    b.extent_management,
                    b.allocation_type,
                    b.initial_extent,
                    b.next_extent,
                    max(a.bytes) largest
                FROM
                    dba_free_space a,
                    dba_tablespaces b
                WHERE
                    b.tablespace_name = a.tablespace_name
                AND
                    b.status = 'ONLINE'
                GROUP BY
                    b.tablespace_name,
                    b.extent_management,
                    b.allocation_type,
                    b.initial_extent,
                    b.next_extent
              ) freespace
          WHERE
              b.owner = ext.owner
          AND
              b.segment_type = ext.segment_type
          AND
              b.segment_name = ext.segment_name
          AND
              b.tablespace_name = ext.tablespace_name
          AND
              -- so landet nur das jeweils letzte extent im ergebnis
              (b.extents - 1) = ext.extent_id
          AND
              b.tablespace_name = freespace.tablespace_name
          AND
              freespace.tablespace_name = ?
          ORDER BY
              b.tablespace_name,
              b.segment_type,
              b.segment_name
      }, $params{tablespace}, $params{tablespace}, $params{tablespace});
      foreach (@tablespaceresult) {
        my ($tablespace_name, $segment_type, $object_name, 
            $required_for_next_extent, $largest_free) = @{$_};
        my %thisparams = %params;
        $thisparams{name} = $object_name;
        $thisparams{segment_type} = $segment_type;
        $thisparams{required_for_next_extent} = $required_for_next_extent;
        $thisparams{largest_free} = $largest_free;
        my $segment = DBD::Oracle::Server::Database::Tablespace::Segment->new(
            %thisparams);
        add_segment($segment);
        $num_segments++;
      }
    }
    if (! $num_segments) {
      $initerrors = 1;
      return undef;
    }
  }

}

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    name => $params{name},
    segment_type => $params{segment_type},
    required_for_next_extent => $params{required_for_next_extent},
    largest_free => $params{largest_free},
    num_users_among_top10logicalreads => undef,
    warningrange => $params{warningrange},
    criticalrange => $params{criticalrange},
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  $self->init_nagios();
  if (($params{mode} =~
      /server::database::tablespace::segment::top10logicalreads/) ||
      ($params{mode} =~
      /server::database::tablespace::segment::top10physicalreads/) ||
      ($params{mode} =~
      /server::database::tablespace::segment::top10bufferbusywaits/) ||
      ($params{mode} =~
      /server::database::tablespace::segment::top10rowlockwaits/)) {
    my $sql;
    my $mode = (split(/::/, $params{mode}))[4];
    ##    -- SELECT owner, object_name, object_type, value, statistic_name
    if (DBD::Oracle::Server::return_first_server()->version_is_minimum("10.x")) {
      # this uses oracle analytic function rank() over (),
      #  needs oracle >= 10.x
      # for more information see: 
      # http://kenntwas.de/2010/linux/monitoring/check_oracle_health-seg-top10-abfragen-verbessern/
      $sql = q{
          SELECT DO.owner,
                 DO.object_name,
                 DO.object_type,
                 SS.VALUE,
                 SS.statistic_name
            FROM dba_objects DO,
                 (SELECT *
                    FROM (SELECT S.OBJ#,
                                 s.VALUE,
                                 s.statistic_name,
                                 RANK () OVER (ORDER BY s.VALUE DESC) rk
                            FROM v$segstat s
                           WHERE s.statistic_name = ?
                                 /* reduce data to significant values */
                                 AND VALUE <> 0)
                   WHERE rk <= 10   /* top 10 */
                                              ) SS
           WHERE DO.object_id = SS.obj#
      };
    } else {
      my $sql = q{
          SELECT COUNT(*)
          FROM (select DO.owner, DO.object_name, DO.object_type, SS.value,
              SS.statistic_name, row_number () over (order by value desc) RN
              FROM dba_objects DO, v$segstat SS
              WHERE DO.object_id = SS.obj#
              AND statistic_name = ?)
         WHERE RN <= 10
         AND owner not in
             ('CTXSYS', 'DBSNMP', 'MDDATA', 'MDSYS', 'DMSYS', 'OLAPSYS',
             'ORDPLUGINS', 'ORDSYS', 'OUTLN', 'SI_INFORMTN_SCHEMA',
             'SYS', 'SYSMAN', 'SYSTEM')
      };
      # this is a very heavy operation and de-selecting system users
      # makes it even slower, so we fetch all data and do the filtering
      # later in perl.
      $sql = q{
          select DO.owner, DO.object_name, DO.object_type, SS.value,
              SS.statistic_name
              FROM dba_objects DO, v$segstat SS
              WHERE DO.object_id = SS.obj#
              AND statistic_name = ?
      };
    }
    my $statname = {
      top10logicalreads => "logical reads",
      top10physicalreads => "physical reads",
      top10bufferbusywaits => "buffer busy waits",
      top10rowlockwaits => "row lock waits",
    }->{$mode};
    #$self->{"num_users_among_".$mode} =
    #    $self->{handle}->fetchrow_array($sql, $statname);
    # faster version
    # fetch everything
    my @sortedsessions = reverse sort { $a->[3] <=> $b->[3] } $self->{handle}->fetchall_array($sql, $statname);
    if (scalar(@sortedsessions) > 10) {
      @sortedsessions = (@sortedsessions)[0..9];
    }
    my @usersessions = map { $_->[0] !~ /^(CTXSYS|DBSNMP|MDDATA|MDSYS|DMSYS|OLAPSYS|ORDPLUGINS|ORDSYS|OUTLN|SI_INFORMTN_SCHEMA|SYS|SYSMAN|SYSTEM)$/ ? $_ : () } @sortedsessions;
    $self->{"num_users_among_".$mode} = scalar(@usersessions);
    if (scalar(@sortedsessions) == 0) {
    #if (! defined $self->{"num_users_among_".$mode}) {
      $self->add_nagios_critical(sprintf "unable to read top10: %s", $@);
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if (($params{mode} =~
        /server::database::tablespace::segment::top10logicalreads/) ||
        ($params{mode} =~
        /server::database::tablespace::segment::top10physicalreads/) ||
        ($params{mode} =~
        /server::database::tablespace::segment::top10bufferbusywaits/) ||
        ($params{mode} =~
        /server::database::tablespace::segment::top10rowlockwaits/)) {
      my $mode = (split(/::/, $params{mode}))[4];
      my $statname = {
        top10logicalreads => "logical reads",
        top10physicalreads => "physical reads",
        top10bufferbusywaits => "buffer busy waits",
        top10rowlockwaits => "row lock waits",
      }->{$mode};
      $self->add_nagios(
          $self->check_thresholds(
              $self->{"num_users_among_".$mode}, "1", "9"),
          sprintf "%d user processes among the top10 %s",
              $self->{"num_users_among_".$mode}, $statname);
      $statname =~ s/\s/_/g;
      $self->add_perfdata(sprintf "users_among_top10_%s=%d;%d;%d",
          $statname, $self->{"num_users_among_".$mode},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~
        /server::database::tablespace::segment::extendspace/) {
      if ($self->{required_for_next_extent} > $self->{largest_free}) {
        $self->add_nagios_critical(
            sprintf "segment %s cannot extend", $self->{name});
      }
    }
  }
}


