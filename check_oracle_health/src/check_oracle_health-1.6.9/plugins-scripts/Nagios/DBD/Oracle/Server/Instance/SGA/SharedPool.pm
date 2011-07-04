package DBD::Oracle::Server::Instance::SGA::SharedPool;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance::SGA);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    free => undef,
    reloads => undef,
    pins => undef,
    handle => $params{handle},
    library_cache => undef,
    dictionary_cache => undef,
    parse_soft => undef,
    parse_hard => undef,
    parse_failures => undef,
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
  if ($params{mode} =~ /server::instance::sga::sharedpool::librarycache/) {
    $self->{library_cache} = 
        DBD::Oracle::Server::Instance::SGA::SharedPool::LibraryCache->new(
        %params);
  } elsif ($params{mode} =~ /server::instance::sga::sharedpool::dictionarycache/) {
    $self->{dictionary_cache} = 
        DBD::Oracle::Server::Instance::SGA::SharedPool::DictionaryCache->new(
        %params);
  } elsif ($params{mode} eq "server::instance::sga::sharedpool::free") {
    $self->init_shared_pool_free(%params);
  } elsif ($params{mode} eq "server::instance::sga::sharedpool::reloads") {
    $self->init_shared_pool_reloads(%params);
  } elsif ($params{mode} eq "server::instance::sga::sharedpool::softparse") {
    $self->init_shared_pool_parser(%params);
  }
}

sub init_shared_pool_reloads {
  my $self = shift;
  my %params = @_;
  ($self->{reloads}, $self->{pins}) = $self->{handle}->fetchrow_array(q{
      SELECT SUM(reloads), SUM(pins)
      FROM v$librarycache
      WHERE namespace IN ('SQL AREA','TABLE/PROCEDURE','BODY','TRIGGER')
  });
  if (! defined $self->{reloads}) {
    $self->add_nagios_critical("unable to get sga reloads");
  } else {
    $self->valdiff(\%params, qw(reloads pins));
    $self->{reload_ratio} = $self->{delta_pins} ?
        100 * $self->{delta_reloads} / $self->{delta_pins} : 100;
  }
}

sub init_shared_pool_free {
  my $self = shift;
  my %params = @_;
  if (DBD::Oracle::Server::return_first_server()->version_is_minimum("9.x")) {
    $self->{free_percent} = $self->{handle}->fetchrow_array(q{
        SELECT ROUND(a.bytes / b.sm * 100,2) FROM
          (SELECT bytes FROM v$sgastat 
              WHERE name='free memory' AND pool='shared pool') a,
          (SELECT SUM(bytes) sm FROM v$sgastat 
              WHERE pool = 'shared pool' AND bytes <= 
                  (SELECT bytes FROM v$sgastat 
                      WHERE name='free memory' AND pool='shared pool')) b
    });
  } else {
    # i don't know if the above code works for 8.x, so i leave the old one here
    $self->{free_percent} = $self->{handle}->fetchrow_array(q{
        SELECT ROUND((SUM(DECODE(name, 'free memory', bytes, 0)) /
            SUM(bytes)) * 100,2) FROM v$sgastat where pool = 'shared pool'
    });
  }
  if (! defined $self->{free_percent}) {
    $self->add_nagios_critical("unable to get sga free");
    return undef;
  }
}

sub init_shared_pool_parser {
  my $self = shift;
  my %params = @_;
  ($self->{parse_total}, $self->{parse_hard}, $self->{parse_failures}) = 
      $self->{handle}->fetchrow_array(q{
    SELECT 
      (SELECT value FROM v$sysstat WHERE name = 'parse count (total)'),
      (SELECT value FROM v$sysstat WHERE name = 'parse count (hard)'),
      (SELECT value FROM v$sysstat WHERE name = 'parse count (failures)')
     FROM DUAL
  });
  if (! defined $self->{parse_total}) {
    $self->add_nagios_critical("unable to get parser");
  } else {
    $self->valdiff(\%params, qw(parse_total parse_hard parse_failures));
    $self->{parse_soft_ratio} = $self->{delta_parse_total} ?
      100 * ($self->{delta_parse_total} - $self->{delta_parse_hard}) /
          $self->{delta_parse_total} : 100;
  }
}


sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::sga::sharedpool::librarycache/) {
      $self->{library_cache}->nagios(%params);
      $self->merge_nagios($self->{library_cache});
    } elsif ($params{mode} =~ /server::instance::sga::sharedpool::dictionarycache/) {
      $self->{dictionary_cache}->nagios(%params);
      $self->merge_nagios($self->{dictionary_cache});
    } elsif ($params{mode} eq "server::instance::sga::sharedpool::free") {
      $self->add_nagios(
          $self->check_thresholds($self->{free_percent}, "10:", "5:"),
          sprintf "SGA shared pool free %.2f%%", $self->{free_percent});
      $self->add_perfdata(sprintf "sga_shared_pool_free=%.2f%%;%s;%s",
          $self->{free_percent}, $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} eq "server::instance::sga::sharedpool::reloads") {
      $self->add_nagios(
          $self->check_thresholds($self->{reload_ratio}, "1", "10"),
          sprintf "SGA shared pool reload ratio %.2f%%", $self->{reload_ratio});
      $self->add_perfdata(sprintf "sga_shared_pool_reload_ratio=%.2f%%;%s;%s",
          $self->{reload_ratio}, $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} eq "server::instance::sga::sharedpool::softparse") {
      $self->add_nagios(
          $self->check_thresholds( $self->{parse_soft_ratio}, "98:", "90:"),
          sprintf "Soft parse ratio %.2f%%", $self->{parse_soft_ratio});
      $self->add_perfdata(sprintf "soft_parse_ratio=%.2f%%;%s;%s",
          $self->{parse_soft_ratio},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}

