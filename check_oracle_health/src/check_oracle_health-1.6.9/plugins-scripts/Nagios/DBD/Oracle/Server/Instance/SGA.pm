package DBD::Oracle::Server::Instance::SGA;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    data_buffer => undef,
    shared_pool => undef,
    latches => undef,
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
  if ($params{mode} =~ /server::instance::sga::databuffer/) {
    $self->{data_buffer} = DBD::Oracle::Server::Instance::SGA::DataBuffer->new(
        %params);
  } elsif ($params{mode} =~ /server::instance::sga::sharedpool/) {
    $self->{shared_pool} = DBD::Oracle::Server::Instance::SGA::SharedPool->new(
        %params);
  } elsif ($params{mode} =~ /server::instance::sga::latch/) {
    DBD::Oracle::Server::Instance::SGA::Latch::init_latches(%params);
    if (my @latches =
        DBD::Oracle::Server::Instance::SGA::Latch::return_latches(%params)) {
      $self->{latches} = \@latches;
    } else {
      $self->add_nagios_critical("unable to aquire latch info");
    }
  } elsif ($params{mode} =~ /server::instance::sga::redolog/) {
    $self->{redo_log_buffer} =
        DBD::Oracle::Server::Instance::SGA::RedoLogBuffer->new(%params);
  } elsif ($params{mode} =~ /server::instance::sga::rollbacksegments/) {
    $self->{rollback_segments} =
        DBD::Oracle::Server::Instance::SGA::RollbackSegments->new(%params);
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if ($params{mode} =~ /server::instance::sga::databuffer/) {
    $self->{data_buffer}->nagios(%params);
    $self->merge_nagios($self->{data_buffer});
  } elsif ($params{mode} =~ /server::instance::sga::sharedpool/) {
    $self->{shared_pool}->nagios(%params);
    $self->merge_nagios($self->{shared_pool});
  } elsif ($params{mode} =~ /server::instance::sga::latch::hitratio/) {
    if (! $self->{nagios_level}) {
      my $hitratio = 0;
      foreach (@{$self->{latches}}) {
        $hitratio = $hitratio + $_->{hitratio};
      }
      $hitratio = $hitratio / scalar(@{$self->{latches}});
      $self->add_nagios(
          $self->check_thresholds($hitratio, "98:", "95:"),
          sprintf "SGA latches hit ratio %.2f%%", $hitratio);
      $self->add_perfdata(sprintf "sga_latches_hit_ratio=%.2f%%;%s;%s",
          $hitratio, $self->{warningrange}, $self->{criticalrange});
    }
  } elsif ($params{mode} =~ /server::instance::sga::latch::listlatches/) {
    foreach (sort { $a->{number} <=> $b->{number} } @{$self->{latches}}) {
      printf "%03d %s\n", $_->{number}, $_->{name};
    }
    $self->add_nagios_ok("have fun");
  } elsif ($params{mode} =~ /server::instance::sga::latch/) {
    foreach (@{$self->{latches}}) {
      $_->nagios(%params);
      $self->merge_nagios($_);
    }
  } elsif ($params{mode} =~ /server::instance::sga::redologbuffer/) {
    $self->{redo_log_buffer}->nagios(%params);
    $self->merge_nagios($self->{redo_log_buffer});
  } elsif ($params{mode} =~ /server::instance::sga::rollbacksegments/) {
    $self->{rollback_segments}->nagios(%params);
    $self->merge_nagios($self->{rollback_segments});
  }
}


1;
