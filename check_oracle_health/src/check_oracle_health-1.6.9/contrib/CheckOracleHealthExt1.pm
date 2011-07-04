package MyQueue;

our @ISA = qw(DBD::Oracle::Server);

sub init {
  my $self = shift;
  my %params = @_;
  $self->{running} = 0;
  $self->{waiting} = 0;
  $self->{held} = 20;
  $self->{cancelled} = 0;
  $self->{length} = 100;
  if ($params{mode} =~ /my::queue::status/) {
    ($self->{running}, $self->{waiting}, $self->{held}, $self->{cancelled}) = 
        $self->{handle}->fetchrow_array(q{
          SELECT COUNT(*) FROM queues WHERE 
            status IN ('running', 'waiting', 'held', 'cancelled')
            GROUP BY status 
        });
  } elsif ($params{mode} =~ /my::queue::length/) {
    $self->{length} = $self->{handle}->fetchrow_array(q{
        SELECT COUNT(*) FROM queues
    });
  } elsif ($params{mode} =~ /my::queue::througput/) {
    $self->{processed_items} = $self->{handle}->fetchrow_array(q{
        SELECT processed FROM queue_status
    });
    $self->valdiff(\%params, qw(processed_items));
    # this automatically creates
    # $self->{delta_timestamp}
    #   the time in seconds since the last run of check_oracle_health
    # $self->{delta_processed_items}
    #   the difference between processed_items now and
    #   processed_items when check_oracle_health was run last time
    $self->{throughput} = $self->{delta_processed_items} / $self->{delta_timestamp};
  } else {
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if ($params{mode} =~ /my::queue::status/) {
    if ($self->{held} > 10 || $self->{cancelled} > 10) {
      $self->add_nagios_critical("more than 10 queues are held or cancelled");
    } elsif ($self->{waiting} > 20 && $self->{running} < 3) {
      $self->add_nagios_warning("more than 20 queues are waiting and less than 3 queues are running");
    } else {
      $self->add_nagios_ok("queues are running normal");
    }
    $self->add_perfdata(sprintf "held=%d cancelled=%d waiting=%d running=%d",
        $self->{running}, $self->{waiting}, $self->{held}, $self->{cancelled});
  } elsif ($params{mode} =~ /my::queue::length/) {
    $self->add_nagios(
        $self->check_thresholds($self->{length}, 100, 500),
        sprintf "queue length is %d", $self->{length});
    $self->add_perfdata(sprintf "queuelen=%d;%d;%d",
        $self->{length}, $self->{warningrange}, $self->{criticalrange});
  } elsif ($params{mode} =~ /my::queue::througput/) {
    $self->add_nagios(
        $self->check_thresholds($self->{throughput}, "50:", "10:"),
        sprintf "queue throughput is %d", $self->{throughput});
    $self->add_perfdata(sprintf "throughput=%.2f;%d;%d",
        $self->{throughput}, $self->{warningrange}, $self->{criticalrange});
  } else {
    $self->add_nagios_unknown("unknown mode");
  }
}
