package DBD::Oracle::Server::Database::Tablespace;

use strict;

our @ISA = qw(DBD::Oracle::Server::Database);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  my @tablespaces = ();
  my $initerrors = undef;

  sub add_tablespace {
    push(@tablespaces, shift);
  }

  sub return_tablespaces {
    return reverse 
        sort { $a->{name} cmp $b->{name} } @tablespaces;
  }
  
  sub init_tablespaces {
    my %params = @_;
    my $num_tablespaces = 0;
    if (($params{mode} =~ /server::database::tablespace::usage/) ||
        ($params{mode} =~ /server::database::tablespace::free/) ||
        ($params{mode} =~ /server::database::tablespace::remainingfreetime/) ||
        ($params{mode} =~ /server::database::tablespace::listtablespaces/)) {
      my @tablespaceresult = ();
      if (DBD::Oracle::Server::return_first_server()->version_is_minimum("9.x")) {
        @tablespaceresult = $params{handle}->fetchall_array(q{
            SELECT
                a.tablespace_name         "Tablespace",
                b.status                  "Status",
                b.contents                "Type",
                b.extent_management       "Extent Mgmt",
                a.bytes                   bytes,
                a.maxbytes                bytes_max,
                c.bytes_free + NVL(d.bytes_expired,0)             bytes_free
            FROM
              (
                -- belegter und maximal verfuegbarer platz pro datafile
                -- nach tablespacenamen zusammengefasst
                -- => bytes
                -- => maxbytes
                SELECT
                    a.tablespace_name,
                    SUM(a.bytes)          bytes,
                    SUM(DECODE(a.autoextensible, 'YES', a.maxbytes, 'NO', a.bytes)) maxbytes
                FROM
                    dba_data_files a
                GROUP BY
                    tablespace_name
              ) a,
              sys.dba_tablespaces b,
              (
                -- freier platz pro tablespace
                -- => bytes_free
                SELECT
                    a.tablespace_name,
                    SUM(a.bytes) bytes_free
                FROM
                    dba_free_space a
                GROUP BY
                    tablespace_name
              ) c,
              (
                -- freier platz durch expired extents 
                -- speziell fuer undo tablespaces
                -- => bytes_expired
                SELECT 
                    a.tablespace_name,
                    SUM(a.bytes) bytes_expired
                FROM
                    dba_undo_extents a
                WHERE
                    status = 'EXPIRED' 
                GROUP BY
                    tablespace_name
              ) d
            WHERE
                a.tablespace_name = c.tablespace_name (+)
                AND a.tablespace_name = b.tablespace_name
                AND a.tablespace_name = d.tablespace_name (+)
            UNION ALL
            SELECT
                d.tablespace_name "Tablespace",
                b.status "Status",
                b.contents "Type",
                b.extent_management "Extent Mgmt",
                sum(a.bytes_free + a.bytes_used) bytes,   -- allocated
                SUM(DECODE(d.autoextensible, 'YES', d.maxbytes, 'NO', d.bytes)) bytes_max,
                SUM(a.bytes_free + a.bytes_used - NVL(c.bytes_used, 0)) bytes_free
            FROM
                sys.v_$TEMP_SPACE_HEADER a,
                sys.dba_tablespaces b,
                sys.v_$Temp_extent_pool c,
                dba_temp_files d
            WHERE
                c.file_id(+)             = a.file_id
                and c.tablespace_name(+) = a.tablespace_name
                and d.file_id            = a.file_id
                and d.tablespace_name    = a.tablespace_name
                and b.tablespace_name    = a.tablespace_name
            GROUP BY
                b.status,
                b.contents,
                b.extent_management,
                d.tablespace_name
            ORDER BY
                1
        });
      } elsif (DBD::Oracle::Server::return_first_server()->version_is_minimum("8.x")) {
        @tablespaceresult = $params{handle}->fetchall_array(q{
            SELECT
                a.tablespace_name         "Tablespace",
                b.status                  "Status",
                b.contents                "Type",
                b.extent_management       "Extent Mgmt",
                a.bytes                   bytes,
                a.maxbytes                bytes_max,
                c.bytes_free              bytes_free
            FROM
              (
                -- belegter und maximal verfuegbarer platz pro datafile
                -- nach tablespacenamen zusammengefasst
                -- => bytes
                -- => maxbytes
                SELECT
                    a.tablespace_name,
                    SUM(a.bytes)          bytes,
                    SUM(DECODE(a.autoextensible, 'YES', a.maxbytes, 'NO', a.bytes)) maxbytes
                FROM
                    dba_data_files a
                GROUP BY
                    tablespace_name
              ) a,
              sys.dba_tablespaces b,
              (
                -- freier platz pro tablespace
                -- => bytes_free
                SELECT
                    a.tablespace_name,
                    SUM(a.bytes) bytes_free
                FROM
                    dba_free_space a
                GROUP BY
                    tablespace_name
              ) c
            WHERE
                a.tablespace_name = c.tablespace_name (+)
                AND a.tablespace_name = b.tablespace_name
            UNION ALL
            SELECT
                a.tablespace_name "Tablespace",
                b.status "Status",
                b.contents "Type",
                b.extent_management "Extent Mgmt",
                sum(a.bytes_free + a.bytes_used) bytes,   -- allocated
                d.maxbytes bytes_max,
                SUM(a.bytes_free + a.bytes_used - NVL(c.bytes_used, 0)) bytes_free
            FROM
                sys.v_$TEMP_SPACE_HEADER a,
                sys.dba_tablespaces b,
                sys.v_$Temp_extent_pool c,
                dba_temp_files d
            WHERE
                c.file_id(+)             = a.file_id
                and c.tablespace_name(+) = a.tablespace_name
                and d.file_id            = a.file_id
                and d.tablespace_name    = a.tablespace_name
                and b.tablespace_name    = a.tablespace_name
            GROUP BY
                a.tablespace_name,
                b.status,
                b.contents,
                b.extent_management,
                d.maxbytes
            ORDER BY
                1
        });
      } else {
        @tablespaceresult = $params{handle}->fetchall_array(q{
            SELECT
                a.tablespace_name         "Tablespace",
                b.status                  "Status",
                b.contents                "Type",
                'DICTIONARY'              "Extent Mgmt",
                a.bytes                   bytes,
                a.maxbytes                bytes_max,
                c.bytes_free              bytes_free
            FROM
              (
                -- belegter und maximal verfuegbarer platz pro datafile
                -- nach tablespacenamen zusammengefasst
                -- => bytes
                -- => maxbytes
                SELECT
                    a.tablespace_name,
                    SUM(a.bytes)          bytes,
                    SUM(a.bytes) maxbytes
                FROM
                    dba_data_files a
                GROUP BY
                    tablespace_name
              ) a,
              sys.dba_tablespaces b,
              (
                -- freier platz pro tablespace
                -- => bytes_free
                SELECT
                    a.tablespace_name,
                    SUM(a.bytes) bytes_free
                FROM
                    dba_free_space a
                GROUP BY
                    tablespace_name
              ) c
            WHERE
                a.tablespace_name = c.tablespace_name (+)
                AND a.tablespace_name = b.tablespace_name
        });
      }
      foreach (@tablespaceresult) {
        my ($name, $status, $type, $extentmgmt, $bytes, $bytes_max, $bytes_free) = @{$_};
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if $params{selectname} && lc $params{selectname} ne lc $name;
        }
        # host_filesys_pctAvailable
        my %thisparams = %params;
        $thisparams{name} = $name;
        $thisparams{bytes} = $bytes;
        $thisparams{bytes_max} = $bytes_max;
        $thisparams{bytes_free} = $bytes_free;
        $thisparams{status} = lc $status;
        $thisparams{type} = lc $type;
        $thisparams{extent_management} = lc $extentmgmt;
        my $tablespace = DBD::Oracle::Server::Database::Tablespace->new(
            %thisparams);
        add_tablespace($tablespace);
        $num_tablespaces++;
      }
      if (! $num_tablespaces) {
        $initerrors = 1;
        return undef;
      }
    } elsif ($params{mode} =~ /server::database::tablespace::fragmentation/) {
      my @tablespaceresult = $params{handle}->fetchall_array(q{
          SELECT
             tablespace_name,       
             COUNT(*) free_chunks,
             DECODE(
              ROUND((max(bytes) / 1024000),2),
              NULL,0,
              ROUND((MAX(bytes) / 1024000),2)) largest_chunk,
             NVL(ROUND(SQRT(MAX(blocks)/SUM(blocks))*(100/SQRT(SQRT(COUNT(blocks)) )),2),
              0) fragmentation_index
          FROM
             sys.dba_free_space 
          GROUP BY 
             tablespace_name
          ORDER BY 
              2 DESC, 1
      });
      foreach (@tablespaceresult) {
        my ($name, $free_chunks, $largest_chunk, $fragmentation_index) = @{$_};
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if $params{selectname} && lc $params{selectname} ne lc $name;
        }
        my %thisparams = %params;
        $thisparams{name} = $name;
        $thisparams{fsfi} = $fragmentation_index;
        my $tablespace = DBD::Oracle::Server::Database::Tablespace->new(
            %thisparams);
        add_tablespace($tablespace);
        $num_tablespaces++;
      }
      if (! $num_tablespaces) {
        $initerrors = 1;
        return undef;
      }
    } elsif ($params{mode} =~ /server::database::tablespace::segment::top10/) {
      my %thisparams = %params;
      $thisparams{name} = "dummy_segment";
      $thisparams{segments} = [];
      my $tablespace = DBD::Oracle::Server::Database::Tablespace->new(
          %thisparams);
      add_tablespace($tablespace);
    } elsif ($params{mode} =~
        /server::database::tablespace::segment::extendspace/) {
      my @tablespaceresult = $params{handle}->fetchall_array(q{
          SELECT
              tablespace_name, extent_management, allocation_type 
          FROM
              dba_tablespaces
      });
      foreach (@tablespaceresult) {
        my ($name, $extent_management, $allocation_type) = @{$_};
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if $params{selectname} && lc $params{selectname} ne lc $name;
        }
        my %thisparams = %params;
        $thisparams{name} = $name;
        $thisparams{extent_management} = $extent_management;
        $thisparams{allocation_type} = $allocation_type;
        my $tablespace = DBD::Oracle::Server::Database::Tablespace->new(
            %thisparams);
        add_tablespace($tablespace);
        $num_tablespaces++;
      }
      if (! $num_tablespaces) {
        $initerrors = 1;
        return undef;
      }
    } elsif ($params{mode} =~ /server::database::tablespace::datafile/) {
      my %thisparams = %params;
      $thisparams{name} = "dummy_for_datafiles";
      $thisparams{datafiles} = [];
      my $tablespace = DBD::Oracle::Server::Database::Tablespace->new(
          %thisparams);
      add_tablespace($tablespace);
    } elsif ($params{mode} =~ /server::database::tablespace::iobalance/) {
      my @tablespaceresult = $params{handle}->fetchall_array(q{
          SELECT tablespace_name FROM dba_tablespaces
      });
      foreach (@tablespaceresult) {
        my ($name) = @{$_};
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if $params{selectname} && lc $params{selectname} ne lc $name;
        }
        my %thisparams = %params;
        $thisparams{name} = $name;
        my $tablespace = DBD::Oracle::Server::Database::Tablespace->new(
            %thisparams);
        add_tablespace($tablespace);
        $num_tablespaces++;
      }
      if (! $num_tablespaces) {
        $initerrors = 1;
        return undef;
      }
    }
  }
}

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    verbose => $params{verbose},
    handle => $params{handle},
    name => $params{name},
    bytes => $params{bytes},
    bytes_max => $params{bytes_max},
    bytes_free => $params{bytes_free} || 0,
    extent_management => $params{extent_management},
    type => $params{type},
    status => $params{status},
    fsfi => $params{fsfi},
    segments => [],
    datafiles => [],
    io_total => 0,
    usage_history => [],
    allocation_type => $params{allocation_type},
    largest_free_extent => $params{largest_free_extent},
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
  $self->set_local_db_thresholds(%params);
  if ($params{mode} =~ /server::database::tablespace::(usage|free)/) {
    if (! defined $self->{bytes_max}) {
      $self->{bytes} = 0;
      $self->{bytes_max} = 0;
      $self->{bytes_free} = 0;
      $self->{percent_used} = 0;
      $self->{real_bytes_max} = $self->{bytes};
      $self->{real_bytes_free} = $self->{bytes_free};
      $self->{percent_as_bar} = '____________________';
    } else {
      # (total - free) / total * 100 = % used
      # (used + free - free) / ( used + free)
      if ($self->{bytes_max} == 0) { 
        $self->{percent_used} =
            ($self->{bytes} - $self->{bytes_free}) / $self->{bytes} * 100;
        $self->{real_bytes_max} = $self->{bytes};
        $self->{real_bytes_free} = $self->{bytes_free};
      } elsif ($self->{bytes_max} > $self->{bytes}) {
        $self->{percent_used} =
            ($self->{bytes} - $self->{bytes_free}) / $self->{bytes_max} * 100;
        $self->{real_bytes_max} = $self->{bytes_max};    
        $self->{real_bytes_free} = $self->{bytes_free} + ($self->{bytes_max} - $self->{bytes});
      } else {
        # alter tablespace USERS add datafile 'users02.dbf'
        #     size 5M autoextend on next 200K maxsize 6M;
        # bytes = 5M, maxbytes = 6M
        # ..... data arriving...until ORA-01652: unable to extend temp segment
        # bytes = 6M, maxbytes = 6M
              # alter database datafile 5 resize 8M;
        # bytes = 8M, maxbytes = 6M
        $self->{percent_used} =
            ($self->{bytes} - $self->{bytes_free}) / $self->{bytes} * 100;
        $self->{real_bytes_max} = $self->{bytes};
        $self->{real_bytes_free} = $self->{bytes_free};
      }
    }
    $self->{percent_free} = 100 - $self->{percent_used};
    my $tlen = 20;
    my $len = int((($params{mode} =~ /server::database::tablespace::usage/) ?
        $self->{percent_used} : $self->{percent_free} / 100 * $tlen) + 0.5);
    $self->{percent_as_bar} = '=' x $len . '_' x ($tlen - $len);
  } elsif ($params{mode} =~ /server::database::tablespace::fragmentation/) {
  } elsif ($params{mode} =~ /server::database::tablespace::segment::top10/) {
    DBD::Oracle::Server::Database::Tablespace::Segment::init_segments(%params);
    if (my @segments =
        DBD::Oracle::Server::Database::Tablespace::Segment::return_segments()) {
      $self->{segments} = \@segments;
    } else {
      $self->add_nagios_critical("unable to aquire segment info");
    }
  } elsif ($params{mode} =~ /server::database::tablespace::datafile/) {
    DBD::Oracle::Server::Database::Tablespace::Datafile::init_datafiles(%params);
    if (my @datafiles =
        DBD::Oracle::Server::Database::Tablespace::Datafile::return_datafiles()) {
      $self->{datafiles} = \@datafiles;
    } else {
      $self->add_nagios_critical("unable to aquire datafile info");
    }
  } elsif ($params{mode} =~ /server::database::tablespace::iobalance/) {
    $params{tablespace} = $self->{name};
    DBD::Oracle::Server::Database::Tablespace::Datafile::init_datafiles(%params);
    if (my @datafiles =
        DBD::Oracle::Server::Database::Tablespace::Datafile::return_datafiles()) {
      $self->{datafiles} = \@datafiles;
      map { $self->{io_total} += $_->{io_total} } @datafiles;
      DBD::Oracle::Server::Database::Tablespace::Datafile::clear_datafiles();
    } else {
      $self->add_nagios_critical("unable to aquire datafile info");
    }
  } elsif ($params{mode} =~ /server::database::tablespace::segment::extendspace/) {
    $params{tablespace} = $self->{name};
    DBD::Oracle::Server::Database::Tablespace::Segment::init_segments(%params);
    my @segments =
        DBD::Oracle::Server::Database::Tablespace::Segment::return_segments();
    $self->{segments} = \@segments;
    DBD::Oracle::Server::Database::Tablespace::Segment::clear_segments();
  } elsif ($params{mode} =~ /server::database::tablespace::remainingfreetime/) {
    # load historical data
    # calculate slope, intercept (go back periods * interval)
    # calculate remaining time
    $self->{percent_used} = $self->{bytes_max} == 0 ?
        ($self->{bytes} - $self->{bytes_free}) / $self->{bytes} * 100 :
        ($self->{bytes} - $self->{bytes_free}) / $self->{bytes_max} * 100;
    $self->{usage_history} = $self->load_state( %params ) || [];
    my $now = time;
    my $lookback = ($params{lookback} || 30) * 24 * 3600;
    #$lookback = 91 * 24 * 3600;
    if (scalar(@{$self->{usage_history}})) {
      $self->trace(sprintf "loaded %d data sets from     %s - %s", 
          scalar(@{$self->{usage_history}}),
          scalar localtime((@{$self->{usage_history}})[0]->[0]),
          scalar localtime($now));
      # only data sets with valid usage. only newer than 91 days
      $self->{usage_history} = 
          [ grep { defined $_->[1] && ($now - $_->[0]) < $lookback } @{$self->{usage_history}} ];
      $self->trace(sprintf "trimmed to %d data sets from %s - %s", 
          scalar(@{$self->{usage_history}}),
          scalar localtime((@{$self->{usage_history}})[0]->[0]),
          scalar localtime($now));
    } else {
      $self->trace(sprintf "no historical data found");
    }
    push(@{$self->{usage_history}}, [ time, $self->{percent_used} ]);
    $params{save} = $self->{usage_history};
    $self->save_state(%params);
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::database::tablespace::usage/) {
      if (! $self->{bytes_max}) {
        $self->check_thresholds($self->{percent_used}, "90", "98");
        if ($self->{status} eq 'offline') {
          $self->add_nagios_warning(
              sprintf("tbs %s is offline", $self->{name})
          );
        } else {
          $self->add_nagios_critical(
              sprintf("tbs %s has has a problem, maybe needs recovery?", $self->{name})
          );
        }
      } else {
        $self->add_nagios(
            # 'tbs_system_usage_pct'=99.01%;90;98 percent used, warn, crit
            # 'tbs_system_usage'=693MB;630;686;0;700 used, warn, crit, 0, max=total
            $self->check_thresholds($self->{percent_used}, "90", "98"),
            $params{eyecandy} ?
                sprintf("[%s] %s", $self->{percent_as_bar}, $self->{name}) :
                sprintf("tbs %s usage is %.2f%%",
                    $self->{name}, $self->{percent_used})
        );
      }
      $self->add_perfdata(sprintf "\'tbs_%s_usage_pct\'=%.2f%%;%d;%d",
          lc $self->{name},
          $self->{percent_used},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "\'tbs_%s_usage\'=%dMB;%d;%d;%d;%d",
          lc $self->{name},
          ($self->{bytes} - $self->{bytes_free}) / 1048576,
          $self->{warningrange} * $self->{bytes_max} / 100 / 1048576,
          $self->{criticalrange} * $self->{bytes_max} / 100 / 1048576,
          0, $self->{bytes_max} / 1048576);
      $self->add_perfdata(sprintf "\'tbs_%s_alloc\'=%dMB;;;0;%d",
          lc $self->{name},
          $self->{bytes} / 1048576,
          $self->{bytes_max} / 1048576);
    } elsif ($params{mode} =~ /server::database::tablespace::fragmentation/) {
      $self->add_nagios(
          $self->check_thresholds($self->{fsfi}, "30:", "20:"),
          sprintf "tbs %s fsfi is %.2f", $self->{name}, $self->{fsfi});
      $self->add_perfdata(sprintf "\'tbs_%s_fsfi\'=%.2f;%s;%s;0;100",
          lc $self->{name},
          $self->{fsfi},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::database::tablespace::free/) {
      # ->percent_free
      # ->real_bytes_max
      #
      # ausgabe
      #   perfdata tbs_<tbs>_free_pct
      #   perfdata tbs_<tbs>_free        (real_bytes_max - bytes) + bytes_free  (with units)
      #   perfdata tbs_<tbs>_alloc_free  bytes_free (with units)
      #
	      # umrechnen der thresholds
      # ()/%
      # MB
      # GB
      # KB
      if (($self->{warningrange} && $self->{warningrange} !~ /^\d+:/) ||
          ($self->{criticalrange} && $self->{criticalrange} !~ /^\d+:/)) {
        $self->add_nagios_unknown("you want an alert if free space is _above_ a threshold????");
        return;
      }
      if (! $params{units}) {
        $params{units} = "%";
      }
      $self->{warning_bytes} = 0;
      $self->{critical_bytes} = 0;
      if ($params{units} eq "%") {
        if (! $self->{bytes_max}) {
          $self->check_thresholds($self->{percent_used}, "5:", "2:");
          if ($self->{status} eq 'offline') {
            $self->add_nagios_warning(
                sprintf("tbs %s is offline", $self->{name})
            );
          } else {
            $self->add_nagios_critical(
                sprintf("tbs %s has has a problem, maybe needs recovery?", $self->{name}) 
            );
          }
        } else {
          $self->add_nagios(
              $self->check_thresholds($self->{percent_free}, "5:", "2:"),
              sprintf("tbs %s has %.2f%% free space left",
                  $self->{name}, $self->{percent_free})
          );
        }
        $self->{warningrange} =~ s/://g;
        $self->{criticalrange} =~ s/://g;
        $self->add_perfdata(sprintf "\'tbs_%s_free_pct\'=%.2f%%;%d:;%d:",
            lc $self->{name},
            $self->{percent_free},
            $self->{warningrange}, $self->{criticalrange});
        $self->add_perfdata(sprintf "\'tbs_%s_free\'=%dMB;%.2f:;%.2f:;0;%.2f",
            lc $self->{name},
            $self->{real_bytes_free} / 1048576,
            $self->{warningrange} * $self->{bytes_max} / 100 / 1048576,
            $self->{criticalrange} * $self->{bytes_max} / 100 / 1048576,
            $self->{real_bytes_max} / 1048576);
      } else {
        my $factor = 1024 * 1024; # default MB
        if ($params{units} eq "GB") {
          $factor = 1024 * 1024 * 1024;
        } elsif ($params{units} eq "MB") {
          $factor = 1024 * 1024;
        } elsif ($params{units} eq "KB") {
          $factor = 1024;
        }
        $self->{warningrange} ||= "5:";
        $self->{criticalrange} ||= "2:";
        my $saved_warningrange = $self->{warningrange};
        my $saved_criticalrange = $self->{criticalrange};
        # : entfernen weil gerechnet werden muss
        $self->{warningrange} =~ s/://g;
        $self->{criticalrange} =~ s/://g;
        $self->{warningrange} = $self->{warningrange} ?
            $self->{warningrange} * $factor : 5 * $factor;
        $self->{criticalrange} = $self->{criticalrange} ?
            $self->{criticalrange} * $factor : 2 * $factor;
        if (! $self->{bytes_max}) {
          $self->{percent_warning} = 0;
          $self->{percent_critical} = 0;
          $self->{warningrange} .= ':';
          $self->{criticalrange} .= ':';
          $self->check_thresholds($self->{real_bytes_free}, "5242880:", "1048576:");      
          if ($self->{status} eq 'offline') {
            $self->add_nagios_warning(
                sprintf("tbs %s is offline", $self->{name})
            );
          } else {
            $self->add_nagios_critical(
                sprintf("tbs %s has a problem, maybe needs recovery?", $self->{name})     
            );
          }
        } else {
          $self->{percent_warning} = 100 * $self->{warningrange} / $self->{real_bytes_max};
          $self->{percent_critical} = 100 * $self->{criticalrange} / $self->{real_bytes_max};
          $self->{warningrange} .= ':';
          $self->{criticalrange} .= ':';
          $self->add_nagios(
              $self->check_thresholds($self->{real_bytes_free}, "5242880:", "1048576:"),  
                  sprintf("tbs %s has %.2f%s free space left", $self->{name},
                      $self->{real_bytes_free} / $factor, $params{units})
          );
        }
	$self->{warningrange} = $saved_warningrange;
        $self->{criticalrange} = $saved_criticalrange;
        $self->{warningrange} =~ s/://g;
        $self->{criticalrange} =~ s/://g;
        $self->add_perfdata(sprintf "\'tbs_%s_free_pct\'=%.2f%%;%.2f:;%.2f:",
            lc $self->{name},
            $self->{percent_free}, $self->{percent_warning}, 
            $self->{percent_critical});
        $self->add_perfdata(sprintf "\'tbs_%s_free\'=%.2f%s;%.2f:;%.2f:;0;%.2f",
            lc $self->{name},
            $self->{real_bytes_free} / $factor, $params{units},
            $self->{warningrange},
            $self->{criticalrange},
            $self->{real_bytes_max} / $factor);
      }
    } elsif ($params{mode} =~ /server::database::tablespace::fragmentation/) {
      $self->add_nagios(
          $self->check_thresholds($self->{fsfi}, "30:", "20:"),
          sprintf "tbs %s fsfi is %.2f", $self->{name}, $self->{fsfi});
      $self->add_perfdata(sprintf "\'tbs_%s_fsfi\'=%.2f;%s;%s;0;100",
          lc $self->{name},
          $self->{fsfi},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::database::tablespace::segment::top10/) {
      foreach (@{$self->{segments}}) {
        $_->nagios(%params);
        $self->merge_nagios($_);
      }
    } elsif ($params{mode} =~ /server::database::tablespace::datafile::listdatafiles/) {
      foreach (sort { $a->{name} cmp $b->{name}; }  @{$self->{datafiles}}) {
        printf "%s\n", $_->{name};
      }
      $self->add_nagios_ok("have fun");
    } elsif ($params{mode} =~ /server::database::tablespace::datafile/) {
      foreach (@{$self->{datafiles}}) {
        $_->nagios(%params);
        $self->merge_nagios($_);
      }
    } elsif ($params{mode} =~ /server::database::tablespace::iobalance/) {
      my $cv = 0;
      if (scalar(@{$self->{datafiles}}) == 0) {
        $self->add_nagios($self->check_thresholds($cv, 50, 100),
            sprintf "%s has no datafiles", $self->{name});
      } elsif (scalar(@{$self->{datafiles}}) == 1) {
        $self->add_nagios($self->check_thresholds($cv, 50, 100),
            sprintf "%s has just 1 datafile", $self->{name});
      } elsif ($self->{io_total} == 0) {
        # nix los
        $self->check_thresholds(0, 50, 100);
        $self->add_nagios_ok(sprintf "%s datafiles io is well balanced",
            $self->{name});
      } else {
        my @unbalanced_datafiles = ();
        my $worstfactor = 0;
        my $level = $ERRORS{OK};
        # http://de.wikipedia.org/wiki/Standardabweichung_der_Grundgesamtheit
        # http://de.wikipedia.org/wiki/Variationskoeffizient
        
        # arithmetisches mittel der stichprobe "x quer"
        my $averagetotal = $self->{io_total} / scalar(@{$self->{datafiles}});

        # standardabweichung
        my $sum = 0;
        foreach (@{$self->{datafiles}}) {
          $sum += ($_->{io_total} - $averagetotal) ** 2;
        }
        my $sx = sqrt ($sum / (scalar(@{$self->{datafiles}}) - 1));

        # relative standardabweichung (%RSD)
        $cv = $sx / $averagetotal * 100;

        # jetzt werden diejenigen datafiles ermittelt, die aus der reihe tanzen
        # wie verhaelt sich ihre differenz zum mittelwert zur standardabweichung
        foreach my $datafile (@{$self->{datafiles}}) {
	  my $delta = abs($datafile->{io_total} - $averagetotal);
          my $factor = $delta / $sx * 100;
          $worstfactor = $factor unless $factor <= $worstfactor;
          if ($self->check_thresholds($factor, 50, 100)) {
            push(@unbalanced_datafiles, $datafile);
          }
        }
        if ($self->check_thresholds($worstfactor, 50, 100)) {
          $self->add_nagios($self->check_thresholds($worstfactor, 50, 100),
              sprintf "%s datafiles %s io unbalanced (%f)", $self->{name},
              join(",", map { $_->{name} } @unbalanced_datafiles), $worstfactor);
        } else {
          $self->add_nagios_ok(sprintf "%s datafiles io is well balanced",
              $self->{name});
        }
      }
      # coefficient of variation (cv)
      $self->add_perfdata(sprintf "\'tbs_%s_io_cv\'=%.2f%%;%.2f;%.2f",
          $self->{name}, $cv,
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ 
        /server::database::tablespace::remainingfreetime/) {
      my $lookback = $params{lookback} || 30;
      my $enoughvalues = 0;
      my $newest = time - $lookback * 24 * 3600; 
      my @tmp = grep { $_->[0] > $newest } @{$self->{usage_history}};
      $self->trace(sprintf "found %d usable data sets since %s",
          scalar(@tmp), scalar localtime($newest));
      if ((scalar(@{$self->{usage_history}}) - scalar(@tmp) > 0) && 
        (scalar(@tmp) >= 2)) {
        # only if more than two values are available
        # only if we have data really reaching back some days
        # predicting with two values from the last hour makes no sense
        $self->{usage_history} = \@tmp;
        my $remaining = 99999;
        my $now = time; # normalisieren, so dass jetzt x=0
        my $n = 0; my $sumx = 0; my $sumx2 = 0; my $sumxy = 0; my $sumy = 0; my $sumy2 = 0; my $m = 0; my $r = 0; 
        my $start_usage = undef;
        my $stop_usage = undef;
        foreach (@{$self->{usage_history}}) {
          next if $_->[0] < $newest;
          $start_usage = $_->[1] if ! defined $start_usage;
          $stop_usage = $_->[1];
          my $x = ($_->[0] - $now) / (24 * 3600);
          my $y = $_->[1];
          $n++;                  # increment number of data points by 1
          $sumx  += $x;          # compute sum of x
          $sumx2 += $x * $x;     # compute sum of x**2 
          $sumxy += $x * $y;     # compute sum of x * y
          $sumy  += $y;          # compute sum of y
          $sumy2 += $y * $y;     # compute sum of y**2 
        }
        # compute slope
        $m = ($n * $sumxy  -  $sumx * $sumy) / ($n * $sumx2 - $sumx ** 2);
        # compute y-intercept
        $b = ($sumy * $sumx2  -  $sumx * $sumxy) / ($n * $sumx2  -  $sumx ** 2);
        # compute correlation coefficient
        #$r = ($sumxy - $sumx * $sumy / $n) / 
        #    sqrt(($sumx2 - ($sumx ** 2)/$n) * ($sumy2 - ($sumy ** 2)/$n));
        $self->debug(sprintf "slope: %f  y-intersect: %f", $m, $b);
        if (abs($m) <= 0.000001) { # $m == 0 does not work even if $m is 0.000000
          $self->add_nagios_ok("tablespace usage is constant");
        } elsif ($m > 0) {
          $remaining = (100 - $b) / $m;
          $self->add_nagios($self->check_thresholds($remaining, "90:", "30:"), 
              sprintf "tablespace %s will be full in %d days",
              $self->{name}, $remaining);
          $self->add_perfdata(sprintf "\'tbs_%s_days_until_full\'=%d;%s;%s",
              lc $self->{name},
              $remaining,
              $self->{warningrange}, $self->{criticalrange});
        } else {
          $self->add_nagios_ok("tablespace usage is decreasing");
        }
      } else {
        $self->add_nagios_ok("no data available for prediction");
      }
    } elsif ($params{mode} =~ 
        /server::database::tablespace::segment::extendspace/) {
      my $segments = 0;
      my @largesegments = ();
      foreach my $segment (@{$self->{segments}}) {
        $segments++;
        $segment->nagios(%params);
        if ($segment->{nagios_level}) {
          push(@largesegments, $segment->{name});
        }
        #$self->merge_nagios($segment);
      }
      if (! $segments) {
        $self->add_nagios_ok(
            sprintf "tablespace %s has no segments", $self->{name});
      } elsif (@largesegments) {
        if ($self->{allocation_type} ne "SYSTEM") {
          $self->add_nagios_critical(
              sprintf "tablespace %s cannot extend segment(s) %s", $self->{name},
              join(", ", @largesegments));
        } else {
          $self->add_nagios_ok(
              sprintf "tablespace %s free extents are large enough (autoallocate)",
              $self->{name});
        }
      } elsif (! $self->{nagios_level}) {
        $self->add_nagios_ok(
            sprintf "tablespace %s free extents are large enough",
            $self->{name});
      }
    } elsif ($params{mode} =~ /server::database::tablespace::datafile/) {
printf "%s\n", $self->dump();
    }
  }
}


