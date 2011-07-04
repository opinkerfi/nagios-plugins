package DBD::Oracle::Server::Instance::SGA::SharedPool::LibraryCache;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance::SGA::SharedPool);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    sum_gets => undef,
    sum_gethits => undef,
    sum_pins => undef,
    sum_pinhits => undef,
    get_hitratio => undef,
    pin_hitratio => undef,
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
      /server::instance::sga::sharedpool::librarycache::hitratio/) {
    ($self->{sum_gethits}, $self->{sum_gets}, $self->{sum_pinhits},
        $self->{sum_pins}) = $self->{handle}->fetchrow_array(q{
            SELECT SUM(gethits), SUM(gets), SUM(pinhits), SUM(pins) 
            FROM v$librarycache
        });
    if (! defined $self->{sum_gets} || ! defined $self->{sum_pinhits}) {
      $self->add_nagios_critical("unable to get sga lc");
    } else {
      $self->valdiff(\%params, qw(sum_gets sum_gethits sum_pins sum_pinhits));
      $self->{get_hitratio} = $self->{delta_sum_gets} ? 
          (100 * $self->{delta_sum_gethits} / $self->{delta_sum_gets}) : 0;
      $self->{pin_hitratio} = $self->{delta_sum_pins} ? 
          (100 * $self->{delta_sum_pinhits} / $self->{delta_sum_pins}) : 0;
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ 
        /server::instance::sga::sharedpool::librarycache::hitratio/) {
      $self->add_nagios(
          $self->check_thresholds($self->{get_hitratio}, "98:", "95:"),
          sprintf "SGA library cache hit ratio %.2f%%", $self->{get_hitratio});
      $self->add_perfdata(sprintf "sga_library_cache_hit_ratio=%.2f%%;%s;%s",
          $self->{get_hitratio}, $self->{warningrange}, $self->{criticalrange});
    }
  }
}


1;
