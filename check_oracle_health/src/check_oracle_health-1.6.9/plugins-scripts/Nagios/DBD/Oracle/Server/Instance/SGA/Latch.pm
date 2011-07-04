package DBD::Oracle::Server::Instance::SGA::Latch;

our @ISA = qw(DBD::Oracle::Server::Instance::SGA);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  my @latches = ();
  my $initerrors = undef;

  sub add_latch {
    push(@latches, shift);
  }

  sub return_latches {
    my %params = @_;
    if ($params{mode} =~ /server::instance::sga::latch::contention/) {
      return reverse
          sort { $a->{contention} <=> $b->{contention} } @latches;
    } else {
      return reverse
          sort { $a->{name} cmp $b->{name} } @latches;
    }
  }

  sub init_latches {
    my %params = @_;
    my $num_latches = 0;
    if (($params{mode} =~ /server::instance::sga::latch::contention/) ||
        ($params{mode} =~ /server::instance::sga::latch::waiting/) ||
        ($params{mode} =~ /server::instance::sga::latch::hitratio/) ||
        ($params{mode} =~ /server::instance::sga::latch::listlatches/)) {
      my $sumsleeps = $params{handle}->fetchrow_array(q{
          SELECT SUM(sleeps) FROM v$latch
      });
      my @latchresult = $params{handle}->fetchall_array(q{
        SELECT latch#, name, gets, sleeps, misses, wait_time
        FROM v$latch
      });
      foreach (@latchresult) {
        my ($number, $name, $gets, $sleeps, $misses, $wait_time) = @{$_};
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if ($params{selectname} && (
              ($params{selectname} !~ /^\d+$/ && (lc $params{selectname} ne lc $name)) || 
              ($params{selectname} =~ /^\d+$/ && ($params{selectname} != $number))));
        }
        my %thisparams = %params;
        $thisparams{number} = $number;
        $thisparams{name} = $name;
        $thisparams{gets} = $gets;
        $thisparams{misses} = $misses;
        $thisparams{sleeps} = $sleeps;
        $thisparams{wait_time} = $wait_time;
        $thisparams{sumsleeps} = $sumsleeps;
        my $latch = DBD::Oracle::Server::Instance::SGA::Latch->new(
            %thisparams);
        add_latch($latch);
        $num_latches++;
      }
      if (! $num_latches) {
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
    number => $params{number},
    name => $params{name},
    gets => $params{gets},
    misses => $params{misses},
    sleeps => $params{sleeps},
    wait_time => $params{wait_time},
    sumsleeps => $params{sumsleeps},
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
  if ($params{mode} =~ 
      /server::instance::sga::latch::hitratio/) {
    if (! defined $self->{gets}) {
      $self->add_nagios_critical(
          sprintf "unable to get sga latches %s", $self->{name});
    } else {
      $params{differenciator} = lc $self->{name}.$self->{number};
      $self->valdiff(\%params, qw(gets misses));
      $self->{hitratio} = $self->{delta_gets} ? 
          100 * ($self->{delta_gets} - $self->{delta_misses}) / $self->{delta_gets} : 100;
    }
  } elsif (($params{mode} =~ /server::instance::sga::latch::contention/) ||
      ($params{mode} =~ /server::instance::sga::latch::waiting/)) {
    if (! defined $self->{gets}) {
      $self->add_nagios_critical(
          sprintf "unable to get sga latches %s", $self->{name});
    } else {
      $params{differenciator} = lc $self->{name}.$self->{number};
      $self->valdiff(\%params, qw(gets sleeps misses wait_time sumsleeps));
      # latch contention
      $self->{contention} = $self->{delta_gets} ?
          100 * $self->{delta_misses} / $self->{delta_gets} : 0;
      # latch percent of sleep during the elapsed time
      $self->{sleep_share} = $self->{delta_wait_time} ?
          ((100 * $self->{wait_time}) / 1000) / $self->{delta_timestamp} : 0;
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ 
        /server::instance::sga::latch::hitratio/) {
      $self->add_nagios(
          $self->check_thresholds($self->{hitratio}, "98:", "95:"),
          sprintf "SGA latches hit ratio %.2f%%", $self->{hitratio});
      $self->add_perfdata(sprintf "sga_latches_hit_ratio=%.2f%%;%s;%s",
          $self->{hitratio}, $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ 
        /server::instance::sga::latch::contention/) {
      $self->add_nagios(
          $self->check_thresholds($self->{contention}, "1", "2"),
          sprintf "SGA latch %s (#%d) contention %.2f%%", 
	      $self->{name}, $self->{number}, $self->{contention});
      $self->add_perfdata(sprintf "'latch_%d_contention'=%.2f%%;%s;%s",
          $self->{number}, $self->{contention}, $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "'latch_%d_gets'=%u",
          $self->{number}, $self->{delta_gets});
    } elsif ($params{mode} =~ 
        /server::instance::sga::latch::waiting/) {
      $self->add_nagios(
          $self->check_thresholds($self->{sleep_share}, "0.1", "1"),
          sprintf "SGA latch %s (#%d) sleeping %.6f%% of the time", 
	      $self->{name}, $self->{number}, $self->{sleep_share});
      $self->add_perfdata(sprintf "'latch_%d_sleep_share'=%.6f%%;%s;%s;0;100",
          $self->{number}, $self->{sleep_share}, $self->{warningrange}, $self->{criticalrange});
    }
  }
}


1;
