package DBD::Oracle::Server::Instance::SGA::DataBuffer;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance::SGA);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    sum_physical_reads => undef,
    sum_physical_reads_direct => undef,
    sum_physical_reads_direct_lob => undef,
    sum_session_logical_reads => undef,
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
  if ($params{mode} =~ /server::instance::sga::databuffer::hitratio/) {
    ($self->{sum_physical_reads}, $self->{sum_physical_reads_direct},
        $self->{sum_physical_reads_direct_lob},
        $self->{sum_session_logical_reads}) =
        $self->{handle}->fetchrow_array(q{
          SELECT SUM(DECODE(name, 'physical reads', value, 0)),
              SUM(DECODE(name, 'physical reads direct', value, 0)),
              SUM(DECODE(name, 'physical reads direct (lob)', value, 0)),
              SUM(DECODE(name, 'session logical reads', value, 0))
          FROM sys.v_$sysstat
        });
    if (! defined $self->{sum_physical_reads}) {
      $self->add_nagios_critical("unable to get sga buffer cache");
    } else {
      $self->valdiff(\%params, qw(sum_physical_reads sum_physical_reads_direct
          sum_physical_reads_direct_lob sum_session_logical_reads));
      $self->{hitratio} = $self->{delta_sum_session_logical_reads} ?
          100 - 100 * ((
              $self->{delta_sum_physical_reads} -
              $self->{delta_sum_physical_reads_direct_lob} -
              $self->{delta_sum_physical_reads_direct}) /
              $self->{delta_sum_session_logical_reads}) : 0;
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::sga::databuffer::hitratio/) {
      $self->add_nagios(
          $self->check_thresholds($self->{hitratio}, "98:", "95:"),
          sprintf "SGA data buffer hit ratio %.2f%%", $self->{hitratio});
      $self->add_perfdata(sprintf "sga_data_buffer_hit_ratio=%.2f%%;%s;%s",
          $self->{hitratio}, 
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}


1;
