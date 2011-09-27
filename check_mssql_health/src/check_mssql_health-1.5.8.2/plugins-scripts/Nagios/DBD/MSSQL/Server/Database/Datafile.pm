package DBD::MSSQL::Server::Database::Datafile;

use strict;
use File::Basename;

our @ISA = qw(DBD::MSSQL::Server::Database);

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
        sort { $a->{logicalfilename} cmp $b->{logicalfilename} } @datafiles;
  }

  sub clear_datafiles {
    @datafiles = ();
  }

  sub init_datafiles {
    my %params = @_;
    my $num_datafiles = 0;
    if ($params{mode} =~ /server::database::datafile::listdatafiles/) {
      my @datafileresults = $params{handle}->fetchall_array(q{
DECLARE @DBInfo TABLE
( ServerName VARCHAR(100),
DatabaseName VARCHAR(100),
FileSizeMB INT,
LogicalFileName sysname,
PhysicalFileName NVARCHAR(520),
Status sysname,
Updateability sysname,
RecoveryMode sysname,
FreeSpaceMB INT,
FreeSpacePct VARCHAR(7),
FreeSpacePages INT,
PollDate datetime)

DECLARE @command VARCHAR(5000)

SELECT @command = 'Use [' + '?' + '] SELECT
@@servername as ServerName,
' + '''' + '?' + '''' + ' AS DatabaseName,
CAST(sysfiles.size/128.0 AS int) AS FileSize,
sysfiles.name AS LogicalFileName, sysfiles.filename AS PhysicalFileName,
CONVERT(sysname,DatabasePropertyEx(''?'',''Status'')) AS Status,
CONVERT(sysname,DatabasePropertyEx(''?'',''Updateability'')) AS Updateability,
CONVERT(sysname,DatabasePropertyEx(''?'',''Recovery'')) AS RecoveryMode,
CAST(sysfiles.size/128.0 - CAST(FILEPROPERTY(sysfiles.name, ' + '''' +
       'SpaceUsed' + '''' + ' ) AS int)/128.0 AS int) AS FreeSpaceMB,
CAST(100 * (CAST (((sysfiles.size/128.0 -CAST(FILEPROPERTY(sysfiles.name,
' + '''' + 'SpaceUsed' + '''' + ' ) AS int)/128.0)/(sysfiles.size/128.0))
AS decimal(4,2))) AS varchar(8)) + ' + '''' + '%' + '''' + ' AS FreeSpacePct,
GETDATE() as PollDate FROM dbo.sysfiles'
INSERT INTO @DBInfo
   (ServerName,
   DatabaseName,
   FileSizeMB,
   LogicalFileName,
   PhysicalFileName,
   Status,
   Updateability,
   RecoveryMode,
   FreeSpaceMB,
   FreeSpacePct,
   PollDate)
EXEC sp_MSForEachDB @command

SELECT
   ServerName,
   DatabaseName,
   FileSizeMB,
   LogicalFileName,
   PhysicalFileName,
   Status,
   Updateability,
   RecoveryMode,
   FreeSpaceMB,
   FreeSpacePct,
   PollDate
FROM @DBInfo
ORDER BY
   ServerName,
   DatabaseName
      });
      if (DBD::MSSQL::Server::return_first_server()->windows_server()) {
        fileparse_set_fstype("MSWin32");
      }
      foreach (@datafileresults) {
        my ($servername, $databasename, $filesizemb, $logicalfilename,
            $physicalfilename, $status, $updateability, $recoverymode,
            $freespacemb, $freespacepct, $polldate) = @{$_};
        next if $databasename ne $params{database};
        if ($params{regexp}) {
          #next if $params{selectname} &&
          #    (($name !~ /$params{selectname}/) &&
          #    (basename($name) !~ /$params{selectname}/));
          next if $params{selectname} &&
              ($logicalfilename !~ /$params{selectname}/);
        } else {
          #next if $params{selectname} &&
          #    ((lc $params{selectname} ne lc $name) &&
          #    (lc $params{selectname} ne lc basename($name)));
          next if $params{selectname} &&
              (lc $params{selectname} ne lc $logicalfilename);
        }
        my %thisparams = %params;
        $thisparams{servername} = $servername;
        $thisparams{databasename} = $databasename;
        $thisparams{filesizemb} = $filesizemb;
        $thisparams{logicalfilename} = $logicalfilename;
        $thisparams{servername} = $servername;
        $thisparams{status} = $status;
        $thisparams{updateability} = $updateability;
        $thisparams{recoverymode} = $recoverymode;
        $thisparams{freespacemb} = $freespacemb;
        $thisparams{freespacepct} = $freespacepct;
        $thisparams{polldate} = $polldate;
        my $datafile = 
            DBD::MSSQL::Server::Database::Datafile->new(
            %thisparams);
        add_datafile($datafile);
        $num_datafiles++;
      }
    }
  }

}

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    databasename => $params{databasename},
    filesizemb => $params{filesizemb},
    logicalfilename => $params{logicalfilename},
    physicalfilename => $params{physicalfilename},
    status => $params{status},
    updateability => $params{updateability},
    recoverymode => $params{recoverymode},
    freespacemb => $params{freespacemb},
    freespacepct => $params{freespacepct},
    freespacepages => $params{freespacepages},
    polldate => $params{polldate},
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
  if ($params{mode} =~ /server::database::iobalance/) {
    if (! defined $self->{phyrds}) {
      $self->add_nagios_critical(sprintf "unable to read datafile io %s", $@);
    } else {
      $params{differenciator} = $self->{path};
      $self->valdiff(\%params, qw(phyrds phywrts));
      $self->{io_total} = $self->{delta_phyrds} + $self->{delta_phywrts};
    }
  } elsif ($params{mode} =~ /server::database::datafile::iotraffic/) {
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
    if ($params{mode} =~ /server::database::datafile::iotraffic/) {
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

