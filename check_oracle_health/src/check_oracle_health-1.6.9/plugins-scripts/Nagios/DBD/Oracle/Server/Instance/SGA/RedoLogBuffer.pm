package DBD::Oracle::Server::Instance::SGA::RedoLogBuffer;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance::SGA);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    last_switch_interval => undef,
    redo_buffer_allocation_retries => undef,
    redo_entries => undef,
    retry_ratio => undef,
    redo_size => undef,
    redo_size_per_sec => undef,
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
  if ($params{mode} =~ /server::instance::sga::redologbuffer::switchinterval/) {
    if ($self->instance_rac()) {
      eval {
        # alles was jemals geswitcht hat, letzter switch, zweitletzter switch
        # jetzt - letzter switch = mindestlaenge des naechsten intervals
        # wenn das lang genug ist, dann war das letzte, kurze intervall
        # wohl nur ein ausreisser oder manueller switch
        # derzeit laufendes intervall, letztes intervall, vorletztes intervall
        ($self->{next_switch_interval}, $self->{last_switch_interval}, $self->{nextto_last_switch_interval}) =
            $self->{handle}->fetchrow_array(q {
          WITH temptab AS
          (
            SELECT sequence#, first_time FROM sys.v_$log WHERE status = 'CURRENT'
                AND thread# = ?
            UNION ALL
            SELECT sequence#, first_time FROM sys.v_$log_history 
                WHERE thread# = ?
                ORDER BY first_time DESC
          )
          SELECT 
              (sysdate - a.first_time) * 1440 * 60 thisinterval,
              (a.first_time - b.first_time) * 1440 * 60 lastinterval,
              (b.first_time - c.first_time) * 1440 * 60 nexttolastinterval
          FROM
          (
            SELECT NVL(
              (
                SELECT first_time FROM (
                  SELECT first_time, rownum AS irow FROM temptab WHERE ROWNUM <= 1
                ) WHERE irow = 1
              ) , to_date('20090624','YYYYMMDD')) as first_time FROM dual
          ) a,
          (
            SELECT NVL(
              (
                SELECT first_time FROM (
                  SELECT first_time, rownum AS irow FROM temptab WHERE ROWNUM <= 2
                ) WHERE irow = 2
              ) , to_date('20090624','YYYYMMDD')) as first_time FROM dual
          ) b,
          (
            SELECT NVL(
              (
                SELECT first_time FROM (
                  SELECT first_time, rownum AS irow FROM temptab WHERE ROWNUM <= 3
                ) WHERE irow = 3
              ) , to_date('20090624','YYYYMMDD')) as first_time FROM dual
          ) c
        }, $self->instance_thread(), $self->instance_thread());
      };
    } else {
      eval {
        # alles was jemals geswitcht hat, letzter switch, zweitletzter switch
        # jetzt - letzter switch = mindestlaenge des naechsten intervals
        # wenn das lang genug ist, dann war das letzte, kurze intervall
        # wohl nur ein ausreisser oder manueller switch
        # derzeit laufendes intervall, letztes intervall, vorletztes intervall
        ($self->{next_switch_interval}, $self->{last_switch_interval}, $self->{nextto_last_switch_interval}) =
            $self->{handle}->fetchrow_array(q {
          WITH temptab AS
          (
            SELECT sequence#, first_time FROM sys.v_$log WHERE status = 'CURRENT'
            UNION ALL
            SELECT sequence#, first_time FROM sys.v_$log_history ORDER BY first_time DESC
          )
          SELECT 
              (sysdate - a.first_time) * 1440 * 60 thisinterval,
              (a.first_time - b.first_time) * 1440 * 60 lastinterval,
              (b.first_time - c.first_time) * 1440 * 60 nexttolastinterval
          FROM
          (
            SELECT NVL(
              (
                SELECT first_time FROM (
                  SELECT first_time, rownum AS irow FROM temptab WHERE ROWNUM <= 1
                ) WHERE irow = 1
              ) , to_date('20090624','YYYYMMDD')) as first_time FROM dual
          ) a,
          (
            SELECT NVL(
              (
                SELECT first_time FROM (
                  SELECT first_time, rownum AS irow FROM temptab WHERE ROWNUM <= 2
                ) WHERE irow = 2
              ) , to_date('20090624','YYYYMMDD')) as first_time FROM dual
          ) b,
          (
            SELECT NVL(
              (
                SELECT first_time FROM (
                  SELECT first_time, rownum AS irow FROM temptab WHERE ROWNUM <= 3
                ) WHERE irow = 3
              ) , to_date('20090624','YYYYMMDD')) as first_time FROM dual
          ) c
        });
      };
    }
    if (! defined $self->{last_switch_interval}) {
      $self->add_nagios_critical(
          sprintf "unable to get last switch interval");
    }
  } elsif ($params{mode} =~ /server::instance::sga::redologbuffer::retryratio/) {
    ($self->{redo_buffer_allocation_retries}, $self->{redo_entries}) = 
        $self->{handle}->fetchrow_array(q{
            SELECT a.value, b.value
            FROM v$sysstat a, v$sysstat b  
            WHERE a.name = 'redo buffer allocation retries'  
            AND b.name = 'redo entries'
    });
    if (! defined $self->{redo_buffer_allocation_retries}) {
      $self->add_nagios_critical("unable to get retry ratio");
    } else {
      $self->valdiff(\%params, qw(redo_buffer_allocation_retries redo_entries));
      $self->{retry_ratio} = $self->{delta_redo_entries} ? 
          100 * $self->{delta_redo_buffer_allocation_retries} / $self->{delta_redo_entries} : 0;
    }
  } elsif ($params{mode} =~ /server::instance::sga::redologbuffer::iotraffic/) {
    $self->{redo_size} = $self->{handle}->fetchrow_array(q{
        SELECT value FROM v$sysstat WHERE name = 'redo size'
    });
    if (! defined $self->{redo_size}) {
      $self->add_nagios_critical("unable to get redo size");
    } else {
      $self->valdiff(\%params, qw(redo_size));
      $self->{redo_size_per_sec} =
          $self->{delta_redo_size} / $self->{delta_timestamp};
      # Megabytes / sec
      $self->{redo_size_per_sec} = $self->{redo_size_per_sec} / 1048576;
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~
        /server::instance::sga::redologbuffer::switchinterval/) {
      my $nextlevel = $self->check_thresholds($self->{next_switch_interval}, "600:", "60:");
      my $nexttolastlevel = $self->check_thresholds($self->{nextto_last_switch_interval}, "600:", "60:");
      my $lastlevel = $self->check_thresholds($self->{last_switch_interval}, "600:", "60:");
      if ($lastlevel) {
        # nachschauen, ob sich die situation schon entspannt hat
        if ($nextlevel == 2) {
          # das riecht nach aerger. kann zwar auch daran liegen, weil der check unmittelbar nach dem kurzen switch
          # ausgefuehrt wird, aber dann bleibts beim soft-hard und beim retry schauts schon besser aus.
          if ($self->{next_switch_interval} < 0) {
            # jetzt geht gar nichts mehr
            $self->add_nagios(
                2,
                "Found a redo log with a timestamp in the future!!");
            $self->{next_switch_interval} = 0;
          } else {
              $self->add_nagios(
                  # 10: minutes, 1: minute = 600:, 60:
                  $nextlevel,
                  sprintf "Last redo log file switch interval was %d minutes%s. Next interval presumably >%d minutes",
                      $self->{last_switch_interval} / 60,
                      $self->instance_rac() ? sprintf " (thread %d)", $self->instance_thread() : "",
                      $self->{next_switch_interval} / 60);
          }
        } elsif ($nextlevel == 1) {
          # das kommt daher, weil retry_interval < warningthreshold
          if ($nexttolastlevel) {
            # aber vorher war auch schon was faul. da braut sich vieleicht was zusammen.
            # die warnung ist sicher berechtigt.
            $self->add_nagios(
                $nextlevel,
                sprintf "Last redo log file switch interval was %d minutes%s. Next interval presumably >%d minutes. Second incident in a row.",
                    $self->{last_switch_interval} / 60,
                    $self->instance_rac() ? sprintf " (thread %d)", $self->instance_thread() : "",
                    $self->{next_switch_interval} / 60);
          } else {
            # hier bin ich grosszuegig. vorletztes intervall war ok, letztes intervall war nicht ok.
            # ich rechne mir also chancen aus, dass $nextlevel nur auf warning ist, weil der retry zu schnell
            # nach dem letzten switch stattfindet. sollte sich entspannen und wenns wirklich ein problem gibt
            # dann kommt sowieso wieder ein switch. also erstmal ok.
            $self->add_nagios(
                0,
                sprintf "Last redo log file switch interval was %d minutes%s. Next interval presumably >%d minutes. Probably a single incident.",
                    $self->{last_switch_interval} / 60,
                    $self->instance_rac() ? sprintf " (thread %d)", $self->instance_thread() : "",
                    $self->{next_switch_interval} / 60);
          }
        } else {
          # war wohl ein einzelfall. also gehen wir davon aus, dass das warninglevel nur wegen des retrys
          # unterschritten wurde und der naechste switch wieder lange genug sein wird
          $self->add_nagios(
              $nextlevel, # sollte 0 sein
              sprintf "Last redo log file switch interval was %d minutes%s. Next interval presumably >%d minutes",
                  $self->{last_switch_interval} / 60,
                  $self->instance_rac() ? sprintf " (thread %d)", $self->instance_thread() : "",
                  $self->{next_switch_interval} / 60);
        }
      } else {
        $self->add_nagios(
            $lastlevel,
            sprintf "Last redo log file switch interval was %d minutes%s. Next interval presumably >%d minutes",
                $self->{last_switch_interval} / 60,
                $self->instance_rac() ? sprintf " (thread %d)", $self->instance_thread() : "",
                $self->{next_switch_interval} / 60);
      }
      $self->add_perfdata(sprintf "redo_log_file_switch_interval=%ds;%s;%s",
          $self->{last_switch_interval},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ 
        /server::instance::sga::redologbuffer::retryratio/) {
      $self->add_nagios(
          $self->check_thresholds($self->{retry_ratio}, "1", "10"),
          sprintf "Redo log retry ratio is %.6f%%",$self->{retry_ratio});
      $self->add_perfdata(sprintf "redo_log_retry_ratio=%.6f%%;%s;%s",
          $self->{retry_ratio},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ 
        /server::instance::sga::redologbuffer::iotraffic/) {
      $self->add_nagios(
          $self->check_thresholds($self->{redo_size_per_sec}, "100", "200"),
          sprintf "Redo log io is %.6f MB/sec", $self->{redo_size_per_sec});
      $self->add_perfdata(sprintf "redo_log_io_per_sec=%.6f;%s;%s",
          $self->{redo_size_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}


1;
