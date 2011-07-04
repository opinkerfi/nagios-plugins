package DBD::Oracle::Server::Instance::PGA;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    internals => undef,
    pgas => [],
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
  if ($params{mode} =~ /server::instance::pga/) {
    $self->{internals} =
        DBD::Oracle::Server::Instance::PGA::Internals->new(%params);
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if ($params{mode} =~ /server::instance::pga/) {
    $self->{internals}->nagios(%params);
    $self->merge_nagios($self->{internals});
  }
}


package DBD::Oracle::Server::Instance::PGA::Internals;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance::PGA);

my $internals; # singleton, nur ein einziges mal instantiierbar

sub new {
  my $class = shift;
  my %params = @_;
  unless ($internals) {
    $internals = {
      handle => $params{handle},
      in_memory_sorts => undef,
      in_disk_sorts => undef,
      in_memory_sort_ratio => undef,
      warningrange => $params{warningrange},
      criticalrange => $params{criticalrange},
    };
    bless($internals, $class);
    $internals->init(%params);
  }
  return($internals);
}

sub init {
  my $self = shift;
  my %params = @_;
  $self->debug("enter init");
  $self->init_nagios();
  if ($params{mode} =~ /server::instance::pga::inmemorysortratio/) {
    ($self->{in_memory_sorts}, $self->{in_disk_sorts}) =
        $self->{handle}->fetchrow_array(q{
        SELECT mem.value, dsk.value 
        FROM v$sysstat mem, v$sysstat dsk
        WHERE mem.name='sorts (memory)' AND dsk.name='sorts (disk)'
    });
    if (! defined $self->{in_memory_sorts}) {
      $self->add_nagios_critical("unable to get pga ratio");
    } else {
      $self->valdiff(\%params, qw(in_memory_sorts in_disk_sorts));
      $self->{in_memory_sort_ratio} =
          ($self->{delta_in_memory_sorts} + $self->{delta_in_disk_sorts}) == 0 ? 100 :
          100 * $self->{delta_in_memory_sorts} /
          ($self->{delta_in_memory_sorts} + $self->{delta_in_disk_sorts});
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::pga::inmemorysortratio/) {
      $self->add_nagios(
          $self->check_thresholds($self->{in_memory_sort_ratio}, "99:", "90:"),
          sprintf "PGA in-memory sort ratio %.2f%%",
          $self->{in_memory_sort_ratio});
      $self->add_perfdata(sprintf "pga_in_memory_sort_ratio=%.2f%%;%s;%s;0;100",
          $self->{in_memory_sort_ratio},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}


1;
