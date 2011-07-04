package DBD::Oracle::Server::Instance::SGA::RollbackSegments;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance::SGA);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

# only create one object with new which stands for all rollback segments

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    gets => undef,
    waits => undef,
    wraps => undef,
    extends => undef,
    undo_header_waits => undef,
    undo_block_waits => undef,
    rollback_segment_hit_ratio => undef,
    rollback_segment_header_contention => undef,
    rollback_segment_block_contention => undef,
    rollback_segment_extents => undef,
    rollback_segment_wraps => undef, 
    rollback_segment_wraps_persec => undef, 
    rollback_segment_extends => undef, 
    rollback_segment_extends_persec => undef, 
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
  if ($params{mode} =~ /server::instance::sga::rollbacksegments::wraps/) {
    $self->{wraps} = $self->{handle}->fetchrow_array(q{
        SELECT SUM(wraps) FROM v$rollstat
    });
    if (! defined $self->{wraps}) {
      $self->add_nagios_critical("unable to get rollback segments stats");
    } else {
      $self->valdiff(\%params, qw(wraps));
      $self->{rollback_segment_wraps} = $self->{delta_wraps};
      $self->{rollback_segment_wraps_persec} = $self->{delta_wraps} / 
         $self->{delta_timestamp};
    }
  } elsif ($params{mode} =~ 
      /server::instance::sga::rollbacksegments::extends/) {
    $self->{extends} = $self->{handle}->fetchrow_array(q{
        SELECT SUM(extends) FROM v$rollstat
    });
    if (! defined $self->{extends}) {
      $self->add_nagios_critical("unable to get rollback segments stats");
    } else {
      $self->valdiff(\%params, qw(extends));
      $self->{rollback_segment_extends} = $self->{delta_extends};
      $self->{rollback_segment_extends_persec} = $self->{delta_extends} /
         $self->{delta_timestamp};
    }
  } elsif ($params{mode} =~
      /server::instance::sga::rollbacksegments::headercontention/) {
    ($self->{undo_header_waits}, $self->{waits})  = $self->{handle}->fetchrow_array(q{
        SELECT ( 
          SELECT SUM(count)
          FROM v$waitstat
          WHERE class = 'undo header' OR class = 'system undo header'
        ) undo, (
          SELECT SUM(count)
          FROM v$waitstat
        ) complete
        FROM DUAL
    });
    if (! defined $self->{undo_header_waits}) {
      $self->add_nagios_critical("unable to get rollback segments wait stats");
    } else {
      $self->valdiff(\%params, qw(undo_header_waits waits));
      $self->{rollback_segment_header_contention} =
          $self->{delta_waits} ? 100 * $self->{delta_undo_header_waits} / $self->{delta_waits} : 0;
    }
  } elsif ($params{mode} =~
      /server::instance::sga::rollbacksegments::blockcontention/) {
    ($self->{undo_block_waits}, $self->{waits})  = $self->{handle}->fetchrow_array(q{
        SELECT ( 
          SELECT SUM(count)
          FROM v$waitstat
          WHERE class = 'undo block' OR class = 'system undo block'
        ) undo, (
          SELECT SUM(count)
          FROM v$waitstat
        ) complete
        FROM DUAL
    });
    if (! defined $self->{undo_block_waits}) { 
      $self->add_nagios_critical("unable to get rollback segments wait stats");
    } else {
      $self->valdiff(\%params, qw(undo_block_waits waits));
      $self->{rollback_segment_block_contention} =
          $self->{delta_waits} ? 100 * $self->{delta_undo_block_waits} / $self->{delta_waits} : 0;
    }
  } elsif ($params{mode} =~
      /server::instance::sga::rollbacksegments::hitratio/) {
    ($self->{waits}, $self->{gets}) = $self->{handle}->fetchrow_array(q{
        SELECT SUM(waits), SUM(gets) FROM v$rollstat
    });
    if (! defined $self->{gets}) {
      $self->add_nagios_critical("unable to get rollback segments wait stats");
    } else {
      $self->valdiff(\%params, qw(waits gets));
      $self->{rollback_segment_hit_ratio} = $self->{delta_gets} ?
          100 - 100 * $self->{delta_waits} / $self->{delta_gets} : 100;
    }
  } elsif ($params{mode} =~
      /server::instance::sga::rollbacksegments::avgactivesize/) {
    if ($params{selectname}) {
      $self->{rollback_segment_optimization_size} = $self->{handle}->fetchrow_array(q{
          SELECT AVG(s.optsize / 1048576) optmization_size
          FROM v$rollstat s, v$rollname n
          WHERE s.usn = n.usn AND n.name != 'SYSTEM' AND n.name = ?
      }, $params{selectname}) || 0;
      $self->{rollback_segment_average_active} = $self->{handle}->fetchrow_array(q{
          SELECT AVG(s.aveactive / 1048576) average_active
          FROM v$rollstat s, v$rollname n
          WHERE s.usn = n.usn AND n.name != 'SYSTEM' AND n.name = ? 
      }, $params{selectname}) || 0;
    } else {
      $self->{rollback_segment_optimization_size} = $self->{handle}->fetchrow_array(q{
          SELECT AVG(s.optsize / 1048576) optmization_size
          FROM v$rollstat s, v$rollname n
          WHERE s.usn = n.usn AND n.name != 'SYSTEM' 
      }) || 0;
      $self->{rollback_segment_average_active} = $self->{handle}->fetchrow_array(q{
          SELECT AVG(s.aveactive / 1048576) average_active
          FROM v$rollstat s, v$rollname n
          WHERE s.usn = n.usn AND n.name != 'SYSTEM'
      }) || 0;
    }
  } else {
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::sga::rollbacksegments::wraps/) {
      if ($params{absolute}) {
        $self->add_nagios(
            $self->check_thresholds(
                $self->{rollback_segment_wraps}, "1", "100"),
            sprintf "Rollback segment wraps %d times",
                $self->{rollback_segment_wraps});
      } else {
        $self->add_nagios(
            $self->check_thresholds(
                $self->{rollback_segment_wraps_persec}, "1", "100"),
            sprintf "Rollback segment wraps %.2f/sec",
                $self->{rollback_segment_wraps_persec});
      }
      $self->add_perfdata(
          sprintf "rollback_segment_wraps=%d;%s;%s",
              $self->{rollback_segment_wraps},
              $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(
          sprintf "rollback_segment_wraps_rate=%.2f;%s;%s",
              $self->{rollback_segment_wraps_persec},
              $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~
        /server::instance::sga::rollbacksegments::extends/) {
      if ($params{absolute}) {
        $self->add_nagios(
            $self->check_thresholds(
                $self->{rollback_segment_extends}, "1", "100"),
            sprintf "Rollback segment extends %d times",
                $self->{rollback_segment_extends});
      } else {
        $self->add_nagios(
            $self->check_thresholds(
                $self->{rollback_segment_extends_persec}, "1", "100"),
            sprintf "Rollback segment extends %.2f/sec",
                $self->{rollback_segment_extends_persec});
      }
      $self->add_perfdata(
          sprintf "rollback_segment_extends=%d;%s;%s",
              $self->{rollback_segment_extends},
              $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(
          sprintf "rollback_segment_extends_rate=%.2f;%s;%s",
              $self->{rollback_segment_extends_persec},
              $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~
        /server::instance::sga::rollbacksegments::headercontention/) {
      $self->add_nagios(
          $self->check_thresholds(
              $self->{rollback_segment_header_contention}, "1", "2"),
          sprintf "Rollback segment header contention is %.2f%%",
              $self->{rollback_segment_header_contention});
      $self->add_perfdata(
          sprintf "rollback_segment_header_contention=%.2f%%;%s;%s",
              $self->{rollback_segment_header_contention},
              $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~
        /server::instance::sga::rollbacksegments::blockcontention/) {
      $self->add_nagios(
          $self->check_thresholds(
              $self->{rollback_segment_block_contention}, "1", "2"),
          sprintf "Rollback segment block contention is %.2f%%",
              $self->{rollback_segment_block_contention});
      $self->add_perfdata(
          sprintf "rollback_segment_block_contention=%.2f%%;%s;%s",
              $self->{rollback_segment_block_contention},
              $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~
        /server::instance::sga::rollbacksegments::hitratio/) {
      $self->add_nagios(
          $self->check_thresholds(
              $self->{rollback_segment_hit_ratio}, "99:", "98:"),
          sprintf "Rollback segment hit ratio is %.2f%%",
              $self->{rollback_segment_hit_ratio});
      $self->add_perfdata(
		  sprintf "rollback_segment_hit_ratio=%.2f%%;%s;%s",
              $self->{rollback_segment_hit_ratio},
              $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~
        /server::instance::sga::rollbacksegments::avgactivesize/) {
      $self->add_nagios_ok(sprintf "Rollback segment average size %.2f MB",
          $self->{rollback_segment_average_active});
      $self->add_perfdata(
          sprintf "rollback_segment_avgsize=%.2f rollback_segment_optsize=%.2f",
              $self->{rollback_segment_average_active},
              $self->{rollback_segment_optimization_size});
    }
  }
}


1;
