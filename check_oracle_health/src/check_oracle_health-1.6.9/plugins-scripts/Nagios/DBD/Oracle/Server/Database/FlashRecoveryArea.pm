package DBD::Oracle::Server::Database::FlashRecoveryArea;

use strict;

our @ISA = qw(DBD::Oracle::Server::Database);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  my @flash_recovery_areas = ();
  my $initerrors = undef;

  sub add_flash_recovery_area {
    push(@flash_recovery_areas, shift);
  }

  sub return_flash_recovery_areas {
    return reverse 
        sort { $a->{name} cmp $b->{name} } @flash_recovery_areas;
  }
  
  sub init_flash_recovery_areas {
    # as far as i understand it, there is only one flra.
    # we use an array here anyway, because the tablespace code can be reused
    my %params = @_;
    my $num_flash_recovery_areas = 0;
    if (($params{mode} =~ /server::database::flash_recovery_area::usage/) ||
        ($params{mode} =~ /server::database::flash_recovery_area::free/) ||
        ($params{mode} =~ /server::database::flash_recovery_area::listflash_recovery_areas/)) {
      my @flash_recovery_arearesult = ();
      if (DBD::Oracle::Server::return_first_server()->version_is_minimum("10.x")) {
        @flash_recovery_arearesult = $params{handle}->fetchall_array(q{
            SELECT
                name, space_limit, space_used, space_reclaimable, number_of_files
            FROM
                v$recovery_file_dest
        });
      } else {
        # no flash before 10.x
      }
      foreach (@flash_recovery_arearesult) {
        my ($name, $space_limit, $space_used, $space_reclaimable,
            $number_of_files) = @{$_};
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if $params{selectname} && lc $params{selectname} ne lc $name;
        }
        my %thisparams = %params;
        $thisparams{name} = $name;
        $thisparams{space_limit} = $space_limit;
        $thisparams{space_used} = $space_used;
        $thisparams{space_reclaimable} = $space_reclaimable;
        $thisparams{number_of_files} = lc $number_of_files;
        my $flash_recovery_area = DBD::Oracle::Server::Database::FlashRecoveryArea->new(
            %thisparams);
        add_flash_recovery_area($flash_recovery_area);
        $num_flash_recovery_areas++;
      }
      if (! $num_flash_recovery_areas) {
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
    verbose => $params{verbose},
    handle => $params{handle},
    name => $params{name},
    space_limit => $params{space_limit},
    space_used => $params{space_used},
    space_reclaimable => $params{space_reclaimable},
    number_of_files => $params{number_of_files},
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
  if ($params{mode} =~ /server::database::flash_recovery_area::(usage|free)/) {
    $self->{percent_used} =
        ($self->{space_used} - $self->{space_reclaimable}) / $self->{space_limit} * 100;
    $self->{percent_free} = 100 - $self->{percent_used};
    $self->{bytes_used} = $self->{space_used} - $self->{space_reclaimable};
    $self->{bytes_free} = $self->{space_limit} - $self->{space_used};
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::database::flash_recovery_area::usage/) {
      $self->check_thresholds($self->{percent_used}, "90", "98");
      $self->add_nagios(
          $self->check_thresholds($self->{percent_used}, "90", "98"),
                sprintf("flra (%s) usage is %.2f%%",
                    $self->{name}, $self->{percent_used}));
      $self->add_perfdata(sprintf "\'flra_usage_pct\'=%.2f%%;%d;%d",
          $self->{percent_used},
          $self->{warningrange}, $self->{criticalrange});
      $self->add_perfdata(sprintf "\'flra_usage\'=%dMB;%d;%d;%d;%d",
          ($self->{space_used} - $self->{space_reclaimable}) / 1048576,
          $self->{warningrange} * $self->{space_limit} / 100 / 1048576,
          $self->{criticalrange} * $self->{space_limit} / 100 / 1048576,
          0, $self->{space_limit} / 1048576);
    } elsif ($params{mode} =~ /server::database::flash_recovery_area::free/) {
      if (($self->{warningrange} && $self->{warningrange} !~ /^\d+:/) || 
          ($self->{criticalrange} && $self->{criticalrange} !~ /^\d+:/)) {
        $self->add_nagios_unknown("you want an alert if free space is _above_ a threshold????");
        return;
      }
      if (! $params{units}) {
        $params{units} = "%";
      }
      $self->{warning_bytes} = 0;
      $self->{critical_bytes} = 0;
      if ($params{units} eq "%") {
        $self->add_nagios(
            $self->check_thresholds($self->{percent_free}, "5:", "2:"),
            sprintf("flra %s has %.2f%% free space left",
                $self->{name}, $self->{percent_free})
        );
        $self->{warningrange} =~ s/://g;
        $self->{criticalrange} =~ s/://g;
        $self->add_perfdata(sprintf "\'flra_free_pct\'=%.2f%%;%d:;%d:",
            $self->{percent_free},
            $self->{warningrange}, $self->{criticalrange});
        $self->add_perfdata(sprintf "\'flra_free\'=%dMB;%.2f:;%.2f:;0;%.2f",
            $self->{bytes_free} / 1048576,
            $self->{warningrange} * $self->{space_limit} / 100 / 1048576,
            $self->{criticalrange} * $self->{space_limit} / 100 / 1048576,
            $self->{space_limit} / 1048576);
      } else {
        my $factor = 1024 * 1024; # default MB
        if ($params{units} eq "GB") {
          $factor = 1024 * 1024 * 1024;
        } elsif ($params{units} eq "MB") {
          $factor = 1024 * 1024;
        } elsif ($params{units} eq "KB") {
          $factor = 1024;
        }
        $self->{warningrange} ||= "5:";
        $self->{criticalrange} ||= "2:";
        my $saved_warningrange = $self->{warningrange};
        my $saved_criticalrange = $self->{criticalrange};
        # : entfernen weil gerechnet werden muss
        $self->{warningrange} =~ s/://g;
        $self->{criticalrange} =~ s/://g;
        $self->{warningrange} = $self->{warningrange} ?
            $self->{warningrange} * $factor : 5 * $factor;
        $self->{criticalrange} = $self->{criticalrange} ?
            $self->{criticalrange} * $factor : 2 * $factor;
        $self->{percent_warning} = 100 * $self->{warningrange} / $self->{space_limit};
        $self->{percent_critical} = 100 * $self->{criticalrange} / $self->{space_limit};
        $self->{warningrange} .= ':';
        $self->{criticalrange} .= ':';
        $self->add_nagios(
            $self->check_thresholds($self->{bytes_free}, "5242880:", "1048576:"),
                sprintf("flra (%s) has %.2f%s free space left", $self->{name},
                    $self->{bytes_free} / $factor, $params{units})
        );
        $self->{warningrange} = $saved_warningrange;
        $self->{criticalrange} = $saved_criticalrange;
        $self->{warningrange} =~ s/://g;
        $self->{criticalrange} =~ s/://g;
        $self->add_perfdata(sprintf "\'flra_free_pct\'=%.2f%%;%.2f:;%.2f:",
            $self->{percent_free}, $self->{percent_warning},
            $self->{percent_critical});
        $self->add_perfdata(sprintf "\'flra_free\'=%.2f%s;%.2f:;%.2f:;0;%.2f",
            $self->{bytes_free} / $factor, $params{units},
            $self->{warningrange},
            $self->{criticalrange},
            $self->{space_limit} / $factor);
      }
    }
  }
}


