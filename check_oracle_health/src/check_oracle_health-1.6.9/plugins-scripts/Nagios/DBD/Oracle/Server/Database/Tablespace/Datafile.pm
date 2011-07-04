package DBD::Oracle::Server::Database::Tablespace::Datafile;

use strict;
use File::Basename;

our @ISA = qw(DBD::Oracle::Server::Database::Tablespace);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  my @datafiles = ();
  my $initerrors = undef;

  sub add_datafile {
    push(@datafiles, shift);
  }

  sub return_datafiles {
    return reverse
        sort { $a->{name} cmp $b->{name} } @datafiles;
  }

  sub clear_datafiles {
    @datafiles = ();
  }

  sub init_datafiles {
    my %params = @_;
    my $num_datafiles = 0;
    if (($params{mode} =~ /server::database::tablespace::datafile::iotraffic/) ||
        ($params{mode} =~ /server::database::tablespace::datafile::listdatafiles/)) {
      # negative values can occur
      # column datafile format a30
      my @datafileresults = $params{handle}->fetchall_array(q{
        SELECT
          name datafile, phyrds reads, phywrts writes
        FROM 
          v$datafile a, v$filestat b 
        WHERE 
          a.file# = b.file#
        UNION
        SELECT
          name datafile, phyrds reads, phywrts writes
        FROM 
          v$tempfile a, v$tempstat b 
        WHERE 
          a.file# = b.file#
      });
      if (DBD::Oracle::Server::return_first_server()->windows_server()) {
        fileparse_set_fstype("MSWin32");
      }
      foreach (@datafileresults) {
        my ($name, $phyrds, $phywrts) = @{$_};
        if ($params{regexp}) {
          next if $params{selectname} &&
              (($name !~ /$params{selectname}/) &&
              (basename($name) !~ /$params{selectname}/));
        } else {
          next if $params{selectname} &&
              ((lc $params{selectname} ne lc $name) &&
              (lc $params{selectname} ne lc basename($name)));
        }
        my %thisparams = %params;
        $thisparams{path} = $name;
        $thisparams{name} = basename($name);
        $thisparams{phyrds} = $phyrds;
        $thisparams{phywrts} = $phywrts;
        my $datafile = 
            DBD::Oracle::Server::Database::Tablespace::Datafile->new(
            %thisparams);
        add_datafile($datafile);
        $num_datafiles++;
      }
    } elsif ($params{mode} =~ /server::database::tablespace::iobalance/) {
      my $sql = q{
           -- SELECT REGEXP_REPLACE(file_name,'^.*.\/.*.\/', '') file_name,
           SELECT file_name,
           SUM(phyrds), SUM(phywrts)
           FROM dba_temp_files, v$filestat 
           WHERE tablespace_name = UPPER(?)
           AND file_id=file# GROUP BY tablespace_name, file_name
           UNION
           -- SELECT REGEXP_REPLACE(file_name,'^.*.\/.*.\/', '') file_name,
           SELECT file_name,
           SUM(phyrds), SUM(phywrts)
           FROM dba_data_files, v$filestat 
           WHERE tablespace_name = UPPER(?)
           AND file_id=file# GROUP BY tablespace_name, file_name };
      if (! DBD::Oracle::Server::return_first_server()->version_is_minimum("9.2.0.3")) {
        # bug 2436600
        $sql = q{
           -- SELECT REGEXP_REPLACE(file_name,'^.*.\/.*.\/', '') file_name,
           SELECT file_name,
           SUM(phyrds), SUM(phywrts)
           FROM dba_data_files, v$filestat 
           WHERE tablespace_name = UPPER(?)
           AND file_id=file# GROUP BY tablespace_name, file_name };
      }
      my @datafileresults = $params{handle}->fetchall_array($sql, $params{tablespace}, $params{tablespace});
      if (DBD::Oracle::Server::return_first_server()->windows_server()) {
        fileparse_set_fstype("MSWin32");
      }
      foreach (@datafileresults) {
        my ($name, $phyrds, $phywrts) = @{$_};
        my %thisparams = %params;
        $thisparams{path} = $name;
        $thisparams{name} = basename($name);
        $thisparams{phyrds} = $phyrds;
        $thisparams{phywrts} = $phywrts;
        my $datafile = 
            DBD::Oracle::Server::Database::Tablespace::Datafile->new(
            %thisparams);
        add_datafile($datafile);
        $num_datafiles++;
      }
      if (! $num_datafiles) {
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
    handle => $params{handle},
    path => $params{path},
    name => $params{name},
    phyrds => $params{phyrds},
    phywrts => $params{phywrts},
    io_total => undef,
    io_total_per_sec => undef,
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
  if ($params{mode} =~ /server::database::tablespace::iobalance/) {
    if (! defined $self->{phyrds}) {
      $self->add_nagios_critical(sprintf "unable to read datafile io %s", $@);
    } else {
      $params{differenciator} = $self->{path};
      $self->valdiff(\%params, qw(phyrds phywrts));
      $self->{io_total} = $self->{delta_phyrds} + $self->{delta_phywrts};
    }
  } elsif ($params{mode} =~ /server::database::tablespace::datafile::iotraffic/) {
    if (! defined $self->{phyrds}) {
      $self->add_nagios_critical(sprintf "unable to read datafile io %s", $@);
    } else {
      $params{differenciator} = $self->{path};
      $self->valdiff(\%params, qw(phyrds phywrts));
      $self->{io_total_per_sec} = ($self->{delta_phyrds} + $self->{delta_phywrts}) /
          $self->{delta_timestamp};
    }
  }
}


sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::database::tablespace::datafile::iotraffic/) {
      $self->add_nagios(
          $self->check_thresholds($self->{io_total_per_sec}, "1000", "5000"),
          sprintf ("%s: %.2f IO Operations per Second", 
              $self->{name}, $self->{io_total_per_sec}));
      $self->add_perfdata(sprintf "'dbf_%s_io_total_per_sec'=%.2f;%d;%d",
          $self->{name}, $self->{io_total_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}

