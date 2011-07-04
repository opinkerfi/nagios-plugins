package DBD::Oracle::Server::Instance::SGA::SharedPool::DictionaryCache;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance::SGA::SharedPool);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    sum_gethits => undef,
    sum_gets => undef,
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
      /server::instance::sga::sharedpool::dictionarycache::hitratio/) {
    ($self->{sum_gets}, $self->{sum_gethits}) =
        $self->{handle}->fetchrow_array(q{
          SELECT SUM(gets), SUM(gets-getmisses) FROM v$rowcache
        });     
    if (! defined $self->{sum_gets}) {
      $self->add_nagios_critical("unable to get sga dc");
    } else {
      $self->valdiff(\%params, qw(sum_gets sum_gethits));
      $self->{hitratio} = $self->{delta_sum_gets} ?
          (100 * $self->{delta_sum_gethits} / $self->{delta_sum_gets}) : 0;
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~
        /server::instance::sga::sharedpool::dictionarycache::hitratio/) {
      $self->add_nagios(
          $self->check_thresholds($self->{hitratio}, "95:", "90:"),
          sprintf "SGA dictionary cache hit ratio %.2f%%", $self->{hitratio});
      $self->add_perfdata(sprintf "sga_dictionary_cache_hit_ratio=%.2f%%;%s;%s",
          $self->{hitratio}, $self->{warningrange}, $self->{criticalrange});
    }
  }
}


1;
