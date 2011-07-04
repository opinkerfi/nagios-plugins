package DBD::Oracle::Server::Instance::Event;

use strict;

our @ISA = qw(DBD::Oracle::Server::Instance);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  my @events = ();
  my $initerrors = undef;

  sub add_event {
    push(@events, shift);
  }

  sub return_events {
    my %params = @_;
    if ($params{mode} =~ /server::instance::event::waits/) {
      return reverse 
          sort { $a->{waits_per_sec} <=> $b->{waits_per_sec} } @events;
    } elsif ($params{mode} =~ /server::instance::event::waiting/) {
      return reverse 
          sort { $a->{percent_waited} <=> $b->{percent_waited} } @events;
    } else {
      return reverse 
          sort { $a->{name} cmp $b->{name} } @events;
    }
  }

  sub init_events {
    my %params = @_;
    my $num_events = 0;
    my %longnames = ();
    if (($params{mode} =~ /server::instance::event::wait/) || #waits, waiting
        ($params{mode} =~ /server::instance::event::listevents/)) {
      my $sql;
      my @idlewaits = ();
      if (DBD::Oracle::Server::return_first_server()->version_is_minimum("10.x")) {
        @idlewaits = map { $_->[0] } $params{handle}->fetchall_array(q{
            SELECT name FROM v$event_name WHERE  wait_class = 'Idle'
        });
      } elsif (DBD::Oracle::Server::return_first_server()->version_is_minimum("9.x")) {
        @idlewaits = (
            'smon timer',
            'pmon timer',
            'rdbms ipc message',
            'Null event',
            'parallel query dequeue',
            'pipe get',
            'client message',
            'SQL*Net message to client',
            'SQL*Net message from client',
            'SQL*Net more data from client',
            'dispatcher timer',
            'virtual circuit status',
            'lock manager wait for remote message',
            'PX Idle Wait',
            'PX Deq: Execution Msg',
            'PX Deq: Table Q Normal',
            'wakeup time manager',
            'slave wait',
            'i/o slave wait',
            'jobq slave wait',
            'null event',
            'gcs remote message',
            'gcs for action',
            'ges remote message',
            'queue messages',
        );
      }
      if ($params{mode} =~ /server::instance::event::listeventsbg/) {
        if (DBD::Oracle::Server::return_first_server()->version_is_minimum("10.x")) {
          $sql = q{
            SELECT e.event_id, e.event, 0, 0, 0, 0 FROM v$session_event e WHERE e.sid IN 
                (SELECT s.sid FROM v$session s WHERE s.type = 'BACKGROUND') GROUP BY e.event, e.event_id
          };
        } else {
          $sql = q{
            SELECT n.event#, e.event, 0, 0, 0, 0 FROM v$session_event e, v$event_name n
            WHERE n.name = e.event AND e.sid IN 
                (SELECT s.sid FROM v$session s WHERE s.type = 'BACKGROUND') GROUP BY e.event, n.event#
          };
        } 
      } else {
        if (DBD::Oracle::Server::return_first_server()->version_is_minimum("10.x")) {
          $sql = q{
            SELECT e.event_id, e.name, 
                NVL(s.total_waits, 0), NVL(s.total_timeouts, 0), NVL(s.time_waited, 0),
                NVL(s.time_waited_micro, 0), NVL(s.average_wait, 0)
            FROM v$event_name e LEFT JOIN sys.v_$system_event s ON e.name = s.event
          };
        } else {
          $sql = q{
            SELECT e.event#, e.name, 
                NVL(s.total_waits, 0), NVL(s.total_timeouts, 0), NVL(s.time_waited, 0),
                NVL(s.time_waited_micro, 0), NVL(s.average_wait, 0)
            FROM v$event_name e LEFT JOIN sys.v_$system_event s ON e.name = s.event
          };
        }
      }
      my @eventresults = $params{handle}->fetchall_array($sql);
      foreach (@eventresults) {
        my ($event_no, $name, $total_waits, $total_timeouts, 
            $time_waited, $time_waited_micro, $average_wait) = @{$_};
	$longnames{$name} = "";
      }
      abbreviate(\%longnames, 2);
      foreach (@eventresults) {
        my ($event_no, $name, $total_waits, $total_timeouts, 
            $time_waited, $time_waited_micro, $average_wait) = @{$_};
        my $shortname = $longnames{$name}->{abbreviation};
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if ($params{selectname} && (
              (($params{selectname} !~ /^\d+$/) &&
                  (! grep /^$params{selectname}$/, map { $longnames{$_}->{abbreviation} } 
                      keys %longnames) &&
                  (lc $params{selectname} ne lc $name)) ||
              (($params{selectname} !~ /^\d+$/) &&
                  (grep /^$params{selectname}$/, map { $longnames{$_}->{abbreviation} } 
                      keys %longnames) &&
                  (lc $params{selectname} ne lc $shortname)) ||
              ($params{selectname} =~ /^\d+$/ &&
                  ($params{selectname} != $event_no))));
        }
        my %thisparams = %params;
        $thisparams{name} = $name;
        $thisparams{shortname} = $shortname;
        $thisparams{event_id} = $event_no;   # bei > 10.x unbedingt event_id aus db holen
        $thisparams{total_waits} = $total_waits;
        $thisparams{total_timeouts} = $total_timeouts;
        $thisparams{time_waited} = $time_waited;
        $thisparams{time_waited_micro} = $time_waited_micro;
        $thisparams{average_wait} = $average_wait;
        $thisparams{idle} = scalar(grep { lc $name =~ /$_/ } @idlewaits);
        my $event = DBD::Oracle::Server::Instance::Event->new(
            %thisparams);
        add_event($event);
        $num_events++;
      }
      if (! $num_events) {
        $initerrors = 1;
        return undef;
      }
    }
  }

  sub begindiff {
    # liefere indices fuer das erste untersch. wort und innerhalb diesem das erste untersch. zeichen
    my @names = @_;
    my $len = 100;
    my $first_diff_word = 0;
    my $first_diff_pos = 0;
    my $smallest_wordcnt = (sort { $a->{wordcnt} <=> $b->{wordcnt} } @names)[0]->{wordcnt};
    foreach my $wordno (0..$smallest_wordcnt-1) {
      my $wordequal = 1;
      my $refword = @{$names[0]->{words}}[$wordno];
      foreach (@names) {
        if (@{$_->{words}}[$wordno] ne $refword) {
          $wordequal = 0;
        }
      }
      $first_diff_word = $wordno;
      if (! $wordequal) {
        last;
      }
    }
    my $smallest_wordlen = 
        length(${(sort { length(${$a->{words}}[$first_diff_word]) <=> length(${$b->{words}}[$first_diff_word])  } @names)[0]->{words}}[$first_diff_word]);
    foreach my $posno (0..$smallest_wordlen-1) {
      my $posequal = 1;
      my $refpos = substr(@{$names[0]->{words}}[$first_diff_word], $posno, 1);
      foreach (@names) {
        if (substr(@{$_->{words}}[$first_diff_word], $posno, 1) ne $refpos) {
          $posequal = 0;
        }
      }
      $first_diff_pos = $posno;
      if (! $posequal) {
        last;
      }
    }
    return ($first_diff_word, $first_diff_pos);
  }

  sub abbreviate {
    #
    # => zeiger auf hash, dessen keys lange namen sind
    # <= gleicher hash mit ausgefuellten eindeutigen values
    #
    my $names = shift;
    my %done = ();
    my $collisions = {};
    foreach my $long (keys %{$names}) {
      # erstmal das noetige werkzeug schmieden
      # und kurzbezeichnungen aus jeweils zwei zeichen bilden
      $names->{$long} = {};
      $names->{$long}->{words} = [
          map { lc }
          map { my $x = $_; $x =~ s/[()\/\-]//g; $x }
          map { /^\-$/ ? () : $_ } 
          split(/_|\s+/, $long) ];
      $names->{$long}->{wordcnt} = scalar (@{$names->{$long}->{words}});
      $names->{$long}->{shortwords} = [ map { substr $_, 0, 2 } @{$names->{$long}->{words}} ];
      $names->{$long}->{abbreviation} = join("_", @{$names->{$long}->{shortwords}});
      $names->{$long}->{unique} = 1;
    }
    individualize($names, -1, -1);
  }

  sub individualize {
    my $names = shift;
    my $delword = shift;
    my $delpos = shift;
    my %done = ();
    my $collisions = {};
    if ($delword >= 0 && $delpos >= 0) {
      # delpos ist die position mit dem ersten unterschied. kann fuer den kuerzesten string 
      # schon nicht mehr existieren.
      map { 
        if (length(${$names->{$_}->{words}}[$delword]) > 2) {
          
          if (length(${$names->{$_}->{words}}[$delword]) == $delpos) {
            ${$names->{$_}->{shortwords}}[$delword] =
                substr(${$names->{$_}->{words}}[$delword], 0, 2)
          } else {
            ${$names->{$_}->{shortwords}}[$delword] =
                substr(${$names->{$_}->{words}}[$delword], 0, 1).
                substr(${$names->{$_}->{words}}[$delword], $delpos);
          }
        }
      } keys %{$names};
    }
    map { $names->{$_}->{abbreviation} = join("_", @{$names->{$_}->{shortwords}}) } keys %{$names};
    map { $done{$names->{$_}->{abbreviation}}++ } keys %{$names};
    map { $names->{$_}->{unique} = $done{$names->{$_}->{abbreviation}} > 1 ? 0 : 1 } keys %{$names};
    #
    #  hash mit abkuerzung als key und array(langnamen, ...) als value.
    #  diese sind nicht eindeutig und muessen noch geschickter abgekuerzt werden
    #
    foreach my $collision (map { $names->{$_}->{unique} ? () : $_ } keys %{$names}) {
      if (! exists $collisions->{$names->{$collision}->{abbreviation}}) {
        $collisions->{$names->{$collision}->{abbreviation}} = [];
      }
      push(@{$collisions->{$names->{$collision}->{abbreviation}}}, $collision);
    }
    #
    # jeweils gruppen mit gemeinsamer, mehrdeutiger abkuerzung werden nochmals gerechnet
    #
    foreach my $collision (keys %{$collisions}) {
      my $newnames = {};
      # hilfestellung, wo es unterschiede gibt
      my($wordnum, $posnum) = begindiff(map { $names->{$_} } @{$collisions->{$collision}});
      map { $newnames->{$_} = 
          $names->{$_} } grep { $names->{$_}->{abbreviation} eq $collision } keys %{$names};
      individualize($newnames, $wordnum, $posnum);
    }
  }

}

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    name => $params{name},
    shortname => $params{shortname},
    event_id => $params{event_id}, # > 10.x
    total_waits => $params{total_waits},
    total_timeouts => $params{total_timeouts},
    time_waited => $params{time_waited}, # divide by 100
    time_waited_micro => $params{time_waited_micro}, # divide by 1000000
    average_wait => $params{average_wait},
    idle => $params{idle} || 0,
    waits_per_sec => undef,
    percent_waited => undef,
    warningrange => $params{warningrange},
    criticalrange => $params{criticalrange},
  };
  #$self->{name} =~ s/^\s+//;
  #$self->{name} =~ s/\s+$//;
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  $self->init_nagios();
  if ($params{mode} =~ /server::instance::event::wait/) {
    if (! defined $self->{total_waits}) {
      $self->add_nagios_critical("unable to get event info");
    } else {
      $params{differenciator} = lc $self->{name};
      $self->valdiff(\%params, qw(total_waits total_timeouts time_waited
          time_waited_micro average_wait));
      $self->{waits_per_sec} = 
          $self->{delta_total_waits} / $self->{delta_timestamp};
      $self->{percent_waited} = 
          100 * ($self->{delta_time_waited_micro} / 1000000 ) / $self->{delta_timestamp};
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::instance::event::waits/) {
      $self->add_nagios(
          $self->check_thresholds($self->{waits_per_sec}, "10", "100"),
          sprintf "%s : %.6f waits/sec", $self->{name}, $self->{waits_per_sec});
      $self->add_perfdata(sprintf "'%s_waits_per_sec'=%.6f;%s;%s",
          $self->{name}, 
          $self->{waits_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::instance::event::waiting/) {
      $self->add_nagios(
          $self->check_thresholds($self->{percent_waited}, "0.1", "0.5"),
          sprintf "%s waits %.6f%% of the time", $self->{name}, $self->{percent_waited});
      $self->add_perfdata(sprintf "'%s_percent_waited'=%.6f%%;%s;%s",
          $self->{name}, 
          $self->{percent_waited},
          $self->{warningrange}, $self->{criticalrange});
    }
  }
}


1;

