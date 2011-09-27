package DBD::MSSQL::Server::Memorypool;

use strict;

our @ISA = qw(DBD::MSSQL::Server);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    buffercache => undef,
    procedurecache => undef,
    locks => [],
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  $self->init_nagios();
  if ($params{mode} =~ /server::memorypool::buffercache/) {
    $self->{buffercache} = DBD::MSSQL::Server::Memorypool::BufferCache->new(
        %params);
  } elsif ($params{mode} =~ /server::memorypool::procedurecache/) {
    $self->{procedurecache} = DBD::MSSQL::Server::Memorypool::ProcedureCache->new(
        %params);
  } elsif ($params{mode} =~ /server::memorypool::lock/) {
    DBD::MSSQL::Server::Memorypool::Lock::init_locks(%params);
    if (my @locks = DBD::MSSQL::Server::Memorypool::Lock::return_locks()) {
      $self->{locks} = \@locks;
    } else {
      $self->add_nagios_critical("unable to aquire lock info");
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if ($params{mode} =~ /server::memorypool::buffercache/) {
    $self->{buffercache}->nagios(%params);
    $self->merge_nagios($self->{buffercache});
  } elsif ($params{mode} =~ /^server::memorypool::lock::listlocks/) {
    foreach (sort { $a->{name} cmp $b->{name}; }  @{$self->{locks}}) {
      printf "%s\n", $_->{name};
    }
    $self->add_nagios_ok("have fun");
  } elsif ($params{mode} =~ /^server::memorypool::lock/) {
    foreach (@{$self->{locks}}) {
      $_->nagios(%params);
      $self->merge_nagios($_);
    }
  }
}


package DBD::MSSQL::Server::Memorypool::BufferCache;

use strict;

our @ISA = qw(DBD::MSSQL::Server::Memorypool);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    hitratio => undef,
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
  if ($params{mode} =~ /server::memorypool::buffercache::hitratio/) {
    #        -- (a.cntr_value * 1.0 / b.cntr_value) * 100.0 [BufferCacheHitRatio]
    $self->{cnt_hitratio} = $self->{handle}->get_perf_counter(
        "SQLServer:Buffer Manager", "Buffer cache hit ratio");
    $self->{cnt_hitratio_base} = $self->{handle}->get_perf_counter(
        "SQLServer:Buffer Manager", "Buffer cache hit ratio base");
    if (! defined $self->{cnt_hitratio}) {
      $self->add_nagios_unknown("unable to aquire buffer cache data");
    } else {
      # das kracht weil teilweise negativ
      #$self->valdiff(\%params, qw(cnt_hitratio cnt_hitratio_base));
      $self->{hitratio} = ($self->{cnt_hitratio_base} == 0) ?
          100 : $self->{cnt_hitratio} / $self->{cnt_hitratio_base} * 100.0;
      # soll vorkommen.....
      $self->{hitratio} = 100 if ($self->{hitratio} > 100);
    }
  } elsif ($params{mode} =~ /server::memorypool::buffercache::lazywrites/) {
    $self->{lazy_writes_s} = $self->{handle}->get_perf_counter(
        "SQLServer:Buffer Manager", "Lazy writes/sec");
    if (! defined $self->{lazy_writes_s}) {
      $self->add_nagios_unknown("unable to aquire buffer manager data");
    } else {
      $self->valdiff(\%params, qw(lazy_writes_s));
      $self->{lazy_writes_per_sec} = $self->{delta_lazy_writes_s} / $self->{delta_timestamp};
    }
  } elsif ($params{mode} =~ /server::memorypool::buffercache::pagelifeexpectancy/) {
    $self->{pagelifeexpectancy} = $self->{handle}->get_perf_counter(
        "SQLServer:Buffer Manager", "Page life expectancy");
    if (! defined $self->{pagelifeexpectancy}) {
      $self->add_nagios_unknown("unable to aquire buffer manager data");
    }
  } elsif ($params{mode} =~ /server::memorypool::buffercache::freeliststalls/) {
    $self->{freeliststalls_s} = $self->{handle}->get_perf_counter(
        "SQLServer:Buffer Manager", "Free list stalls/sec");
    if (! defined $self->{freeliststalls_s}) {
      $self->add_nagios_unknown("unable to aquire buffer manager data");
    } else {
      $self->valdiff(\%params, qw(freeliststalls_s));
      $self->{freeliststalls_per_sec} = $self->{delta_freeliststalls_s} / $self->{delta_timestamp};
    }
  } elsif ($params{mode} =~ /server::memorypool::buffercache::checkpointpages/) {
    $self->{checkpointpages_s} = $self->{handle}->get_perf_counter(
        "SQLServer:Buffer Manager", "Checkpoint pages/sec");
    if (! defined $self->{checkpointpages_s}) {
      $self->add_nagios_unknown("unable to aquire buffer manager data");
    } else {
      $self->valdiff(\%params, qw(checkpointpages_s));
      $self->{checkpointpages_per_sec} = $self->{delta_checkpointpages_s} / $self->{delta_timestamp};
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::memorypool::buffercache::hitratio/) {
      $self->add_nagios(
          $self->check_thresholds($self->{hitratio}, '90:', '80:'),
          sprintf "buffer cache hit ratio is %.2f%%", $self->{hitratio});
      $self->add_perfdata(sprintf "buffer_cache_hit_ratio=%.2f%%;%s;%s",
          $self->{hitratio},
          $self->{warningrange}, $self->{criticalrange});
      #$self->add_perfdata(sprintf "buffer_cache_hit_ratio_now=%.2f%%",
      #    $self->{hitratio_now});
    } elsif ($params{mode} =~ /server::memorypool::buffercache::lazywrites/) {
      $self->add_nagios(
          $self->check_thresholds($self->{lazy_writes_per_sec}, '20', '40'),
          sprintf "%.2f lazy writes per second", $self->{lazy_writes_per_sec});
      $self->add_perfdata(sprintf "lazy_writes_per_sec=%.2f;%s;%s",
          $self->{lazy_writes_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::memorypool::buffercache::pagelifeexpectancy/) {
      $self->add_nagios(
          $self->check_thresholds($self->{pagelifeexpectancy}, '300:', '180:'),
          sprintf "page life expectancy is %d seconds", $self->{pagelifeexpectancy});
      $self->add_perfdata(sprintf "page_life_expectancy=%d;%s;%s",
          $self->{pagelifeexpectancy},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::memorypool::buffercache::freeliststalls/) {
      $self->add_nagios(
          $self->check_thresholds($self->{freeliststalls_per_sec}, '4', '10'),
          sprintf "%.2f free list stalls per second", $self->{freeliststalls_per_sec});
      $self->add_perfdata(sprintf "free_list_stalls_per_sec=%.2f;%s;%s",
          $self->{freeliststalls_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::memorypool::buffercache::checkpointpages/) {
      $self->add_nagios(
          $self->check_thresholds($self->{checkpointpages_per_sec}, '100', '500'),
          sprintf "%.2f pages flushed per second", $self->{checkpointpages_per_sec});
      $self->add_perfdata(sprintf "checkpoint_pages_per_sec=%.2f;%s;%s",
          $self->{checkpointpages_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}





package DBD::MSSQL::Server::Memorypool::Lock;

use strict;

our @ISA = qw(DBD::MSSQL::Server::Memorypool);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  my @locks = ();
  my $initerrors = undef;

  sub add_lock {
    push(@locks, shift);
  }

  sub return_locks {
    return reverse
        sort { $a->{name} cmp $b->{name} } @locks;
  }

  sub init_locks {
    my %params = @_;
    my $num_locks = 0;
    if (($params{mode} =~ /server::memorypool::lock::listlocks/) ||
        ($params{mode} =~ /server::memorypool::lock::waits/) ||
        ($params{mode} =~ /server::memorypool::lock::deadlocks/) ||
        ($params{mode} =~ /server::memorypool::lock::timeouts/)) {
      my @lockresult = $params{handle}->get_instance_names(
          'SQLServer:Locks');
      foreach (@lockresult) {
        my ($name) = @{$_};
        $name =~ s/\s*$//;
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if $params{selectname} && lc $params{selectname} ne lc $name;
        }
        my %thisparams = %params;
        $thisparams{name} = $name;
        my $lock = DBD::MSSQL::Server::Memorypool::Lock->new(
            %thisparams);
        add_lock($lock);
        $num_locks++;
      }
      if (! $num_locks) {
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
    warningrange => $params{warningrange},
    criticalrange => $params{criticalrange},
    name => $params{name},
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  $self->init_nagios();
  if ($params{mode} =~ /server::memorypool::lock::listlocks/) {
    # name reicht
  } elsif ($params{mode} =~ /server::memorypool::lock::waits/) {
    $self->{lock_waits_s} = $self->{handle}->get_perf_counter_instance(
        "SQLServer:Locks", "Lock Waits/sec", $self->{name});
    if (! defined $self->{lock_waits_s}) {
      $self->add_nagios_unknown("unable to aquire counter data");
    } else {
      $self->valdiff(\%params, qw(lock_waits_s));
      $self->{lock_waits_per_sec} = $self->{delta_lock_waits_s} / $self->{delta_timestamp};
    }
  } elsif ($params{mode} =~ /^server::memorypool::lock::timeouts/) {
    $self->{lock_timeouts_s} = $self->{handle}->get_perf_counter_instance(
        "SQLServer:Locks", "Lock Timeouts/sec", $self->{name});
    if (! defined $self->{lock_timeouts_s}) {
      $self->add_nagios_unknown("unable to aquire counter data");
    } else {
      $self->valdiff(\%params, qw(lock_timeouts_s));
      $self->{lock_timeouts_per_sec} = $self->{delta_lock_timeouts_s} / $self->{delta_timestamp};
    }
  } elsif ($params{mode} =~ /^server::memorypool::lock::deadlocks/) {
    $self->{lock_deadlocks_s} = $self->{handle}->get_perf_counter_instance(
        "SQLServer:Locks", "Number of Deadlocks/sec", $self->{name});
    if (! defined $self->{lock_deadlocks_s}) {
      $self->add_nagios_unknown("unable to aquire counter data");
    } else {
      $self->valdiff(\%params, qw(lock_deadlocks_s));
      $self->{lock_deadlocks_per_sec} = $self->{delta_lock_deadlocks_s} / $self->{delta_timestamp};
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::memorypool::lock::waits/) {
      $self->add_nagios(
          $self->check_thresholds($self->{lock_waits_per_sec}, 100, 500),
          sprintf "%.4f lock waits / sec for %s",
          $self->{lock_waits_per_sec}, $self->{name});
      $self->add_perfdata(sprintf "%s_lock_waits_per_sec=%.4f;%s;%s",
          $self->{name}, $self->{lock_waits_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /^server::memorypool::lock::timeouts/) {
      $self->add_nagios(
          $self->check_thresholds($self->{lock_timeouts_per_sec}, 1, 5),
          sprintf "%.4f lock timeouts / sec for %s",
          $self->{lock_timeouts_per_sec}, $self->{name});
      $self->add_perfdata(sprintf "%s_lock_timeouts_per_sec=%.4f;%s;%s",
          $self->{name}, $self->{lock_timeouts_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /^server::memorypool::lock::deadlocks/) {
      $self->add_nagios(
          $self->check_thresholds($self->{lock_deadlocks_per_sec}, 1, 5),
          sprintf "%.4f deadlocks / sec for %s",
          $self->{lock_deadlocks_per_sec}, $self->{name});
      $self->add_perfdata(sprintf "%s_deadlocks_per_sec=%.4f;%s;%s",
          $self->{name}, $self->{lock_deadlocks_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}


package DBD::MSSQL::Server::Memorypool::SystemLevelDataStructures::LockTable;
package DBD::MSSQL::Server::Memorypool::ProcedureCache;
package DBD::MSSQL::Server::Memorypool::LogCache;
package DBD::MSSQL::Server::Memorypool::SystemLevelDataStructures;
