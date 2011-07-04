package DBD::Oracle::Server::Instance::Enqueue;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  my @enqueues = ();
  my $initerrors = undef;

  sub add_enqueue {
    push(@enqueues, shift);
  }

  sub return_enqueues {
    return reverse 
        sort { $a->{name} cmp $b->{name} } @enqueues;
  }

  sub init_enqueues {
    my %params = @_;
    my $num_enqueues = 0;
    if (($params{mode} =~ /server::instance::enqueue::contention/) || 
        ($params{mode} =~ /server::instance::enqueue::waiting/) ||
        ($params{mode} =~ /server::instance::enqueue::listenqueues/)) {
      # ora11 PE FP TA DL SR TQ KT PW XR SS SJ SQ IT IA UL WP RR KM
      #       PD CF SW CT US TD TK JS FS CN DT TS TT JD SE MW AF TL
      #       PV AS TM TX FB JQ MD TO TH PR RO MR DP WF TB SH RS CU
      #       AE CI PG IS RT HW DR FU
      # ora10 PE FP TA DL SR TQ KT PW XR SS SQ PF IT IA UL WP KM PD
      #       CF SW CT US TD AG JS DT TS TT CN JD SE MW AF TL PV AS
      #       TM FB TX JQ MD TO PR RO MR SK DP WF TB SH RS CU AW CI
      #       PG IS RT HW DR FU
      # ora9  CF CI CU DL DP DR DT DX FB HW IA IS IT JD MD MR PE PF
      #       RO RT SQ SR SS SW TA TD TM TO TS TT TX UL US XR
      my @enqueueresults = $params{handle}->fetchall_array(q{
        SELECT inst_id, eq_type, total_req#, total_wait#, 
            succ_req#, failed_req#, cum_wait_time
        FROM v$enqueue_stat
      });
      foreach (@enqueueresults) {
        my ($inst_id, $name, $total_requests, $total_waits,
          $succeeded_requests, $failed_requests, $cumul_wait_time) = @{$_};
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if $params{selectname} && lc $params{selectname} ne lc $name;
        }
        my %thisparams = %params;
        $thisparams{name} = $name;
        $thisparams{total_requests} = $total_requests;
        $thisparams{total_waits} = $total_waits;
        $thisparams{succeeded_requests} = $succeeded_requests;
        $thisparams{failed_requests} = $failed_requests;
        $thisparams{cumul_wait_time} = $cumul_wait_time;
        my $enqueue = DBD::Oracle::Server::Instance::Enqueue->new(
            %thisparams);
        add_enqueue($enqueue);
        $num_enqueues++;
      }
      if (! $num_enqueues) {
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
    name => $params{name},
    total_requests => $params{total_requests},
    total_waits => $params{total_waits},
    succeeded_requests => $params{succeeded_requests},
    failed_requests => $params{failed_requests},
    cumul_wait_time => $params{cumul_wait_time}, # ! milliseconds
    contention => undef,
    percent_waited => undef,
    warningrange => $params{warningrange},
    criticalrange => $params{criticalrange},
  };
  $self->{name} =~ s/^\s+//;
  $self->{name} =~ s/\s+$//;
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  $self->init_nagios();
  if (($params{mode} =~ /server::instance::enqueue::contention/) ||
      ($params{mode} =~ /server::instance::enqueue::waiting/)) {
    $params{differenciator} = lc $self->{name};
    $self->valdiff(\%params, qw(total_requests total_waits succeeded_requests
        failed_requests cumul_wait_time));
    # enqueue contention
    $self->{contention} = $self->{delta_total_requests} ?
        100 * $self->{delta_total_waits} / $self->{delta_total_requests} : 0;
    # enqueue waiting
    $self->{percent_waited} = ($self->{delta_cumul_wait_time} /
        ($self->{delta_timestamp} * 1000)) * 100;
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::enqueue::contention/) {
      $self->add_nagios(
          $self->check_thresholds($self->{contention}, "1", "10"),
          sprintf "enqueue %s %s: %.2f%% of the requests must wait ", 
              $self->{name}, $self->longname(), $self->{contention});
      $self->add_perfdata(sprintf "'%s_contention'=%.2f%%;%s;%s '%s_requests'=%d '%s_waits'=%d",
          $self->{name}, 
          $self->{contention},
          $self->{warningrange}, $self->{criticalrange},
          $self->{name},
          $self->{delta_total_requests},
          $self->{name},
          $self->{delta_total_waits});
    } elsif ($params{mode} =~ /server::instance::enqueue::waiting/) {
      $self->add_nagios(
          # 1 ms wait in 5 minutes
          $self->check_thresholds($self->{percent_waited}, "0.0003333", "0.003333"),
          sprintf "enqueue %s %s: waiting %.4f%% of the time", 
              $self->{name}, $self->longname(), $self->{percent_waited});
      $self->add_perfdata(sprintf "'%s_ms_waited'=%d '%s_pct_waited'=%.4f%%;%s;%s",
          $self->{name}, 
          $self->{delta_cumul_wait_time},
          $self->{name}, 
          $self->{percent_waited},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}


sub longname {
  my $self = shift;
  my $abbrev = <<EOEO;
BL, Buffer Cache Management
BR, Backup/Restore
CF, Controlfile Transaction
CI, Cross-instance Call Invocation
CU, Bind Enqueue
DF, Datafile
DL, Direct Loader Index Creation
DM, Database Mount
DR, Distributed Recovery Process
DX, Distributed Transaction
FP, File Object
FS, File Set
HW, High-Water Lock
IN, Instance Number
IR, Instance Recovery
IS, Instance State
IV, Library Cache Invalidation
JI, Enqueue used during AJV snapshot refresh
JQ, Job Queue
KK, Redo Log "Kick"
KO, Multiple Object Checkpoint
L[A-P], Library Cache Lock
LS, Log Start or Switch
MM, Mount Definition
MR, Media Recovery
N[A-Z], Library Cache Pin
PE, ALTER SYSTEM SET PARAMETER = VALUE
PF, Password File
PI, Parallel Slaves
PR, Process Startup
PS, Parallel Slave Synchronization
Q[A-Z], Row Cache
RO, Object Reuse
RT, Redo Thread
RW, Row Wait
SC, System Commit Number
SM, SMON
SN, Sequence Number
SQ, Sequence Number Enqueue
SR, Synchronized Replication
SS, Sort Segment
ST, Space Management Transaction
SV, Sequence Number Value
TA, Transaction Recovery
TC, Thread Checkpoint
TE, Extend Table
TM, DML Enqueue
TO, Temporary Table Object Enqueue
TS, Temporary Segment (also TableSpace)
TT, Temporary Table
TX, Transaction
UL, User-defined Locks
UN, User Name
US, Undo Segment, Serialization
WL, Being Written Redo Log
XA, Instance Attribute Lock
XI, Instance Registration Lock
EOEO
  my $descriptions = {};
  foreach (split(/\n/, $abbrev)) {
    my ($short, $descr) = split /,/;
    if ($self->{name} =~ /^$short$/) {
      $descr =~ s/^\s+//g;
      return $descr;
    }
  }
  return "";
}

1;
