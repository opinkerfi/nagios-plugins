package DBD::MSSQL::Server::Database;

use strict;

our @ISA = qw(DBD::MSSQL::Server);

my %ERRORS=( OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 );
my %ERRORCODES=( 0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN' );

{
  my @databases = ();
  my $initerrors = undef;

  sub add_database {
    push(@databases, shift);
  }

  sub return_databases {
    return reverse
        sort { $a->{name} cmp $b->{name} } @databases;
  }

  sub init_databases {
    my %params = @_;
    my $num_databases = 0;
    if (($params{mode} =~ /server::database::listdatabases/) ||
        ($params{mode} =~ /server::database::databasefree/) ||
        ($params{mode} =~ /server::database::lastbackup/) ||
        ($params{mode} =~ /server::database::transactions/) ||
        ($params{mode} =~ /server::database::datafile/)) {
      my @databaseresult = ();
      if (DBD::MSSQL::Server::return_first_server()->version_is_minimum("9.x")) {
        @databaseresult = $params{handle}->fetchall_array(q{
          SELECT name, database_id FROM master.sys.databases
        });
      } else {
        #@databaseresult = map {
        #  [ $_->[0], $_->[3] ] # only name, dbid
        #} $params{handle}->fetchall_array(q{exec sp_helpdb});
        @databaseresult = $params{handle}->fetchall_array(q{
          SELECT name, dbid FROM master.dbo.sysdatabases
        });
      }
      if ($params{mode} =~ /server::database::transactions/) {
        push(@databaseresult, [ '_Total', 0 ]);
      }
      foreach (@databaseresult) {
        my ($name, $id) = @{$_};
        next if $params{database} && $name ne $params{database};
        if ($params{regexp}) {
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if $params{selectname} && lc $params{selectname} ne lc $name;
        }
        my %thisparams = %params;
        $thisparams{name} = $name;
        $thisparams{id} = $id;
        my $database = DBD::MSSQL::Server::Database->new(
            %thisparams);
        add_database($database);
        $num_databases++;
      }
      if (! $num_databases) {
        $initerrors = 1;
        return undef;
      }
    } elsif ($params{mode} =~ /server::database::backupage/) {
      my @databaseresult = ();
      if (DBD::MSSQL::Server::return_first_server()->version_is_minimum("9.x")) {
        @databaseresult = $params{handle}->fetchall_array(q{
          SELECT
            a.name, 
            DATEDIFF(HH, MAX(b.backup_finish_date), GETDATE()),
            DATEDIFF(MI, MAX(b.backup_start_date), MAX(b.backup_finish_date))
          FROM sys.sysdatabases a LEFT OUTER JOIN msdb.dbo.backupset b
          ON b.database_name = a.name
          GROUP BY a.name 
          ORDER BY a.name
        });
      } else {
        @databaseresult = $params{handle}->fetchall_array(q{
          SELECT
            a.name, 
            DATEDIFF(HH, MAX(b.backup_finish_date), GETDATE()),
            DATEDIFF(MI, MAX(b.backup_start_date), MAX(b.backup_finish_date))
          FROM master.dbo.sysdatabases a LEFT OUTER JOIN msdb.dbo.backupset b
          ON b.database_name = a.name
          GROUP BY a.name 
          ORDER BY a.name 
        }); 
      }
      foreach (sort {
        if (! defined $b->[1]) {
          return 1;
        } elsif (! defined $a->[1]) {
          return -1;
        } else {
          return $a->[1] <=> $b->[1];
        }
      } @databaseresult) { 
        my ($name, $age, $duration) = @{$_};
        next if $params{database} && $name ne $params{database};
        if ($params{regexp}) { 
          next if $params{selectname} && $name !~ /$params{selectname}/;
        } else {
          next if $params{selectname} && lc $params{selectname} ne lc $name;
        }
        my %thisparams = %params;
        $thisparams{name} = $name;
        $thisparams{backup_age} = $age;
        $thisparams{backup_duration} = $duration;
        my $database = DBD::MSSQL::Server::Database->new(
            %thisparams);
        add_database($database);
        $num_databases++;
      }
    }

  }

}

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    handle => $params{handle},
    warningrange => $params{warningrange},
    criticalrange => $params{criticalrange},
    name => $params{name},
    id => $params{id},
    datafiles => [],
    backup_age => $params{backup_age},
    backup_duration => $params{backup_duration},
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  $self->init_nagios();
  $self->set_local_db_thresholds(%params);
  if ($params{mode} =~ /server::database::datafile/) {
    $params{database} = $self->{name};
    DBD::MSSQL::Server::Database::Datafile::init_datafiles(%params);
    if (my @datafiles = 
        DBD::MSSQL::Server::Database::Datafile::return_datafiles()) {
      $self->{datafiles} = \@datafiles;
    } else {
      $self->add_nagios_critical("unable to aquire datafile info");
    }
  } elsif ($params{mode} =~ /server::database::databasefree/) {
    ###################################################################################
    #                            fuer's museum
    # 1> sp_spaceused
    # 2> go
    # database_name   database_size   unallocated space
    # master  4.50 MB 1.32 MB
    # reserved        data    index_size      unused
    # 2744 KB 1056 KB 1064 KB 624 KB
    # (return status = 0)
    #my($database_name, $database_size, $unallocated_space,
    #    $reserved, $data, $index_size, $unused) =
    #     $params{handle}->fetchrow_array(
    #    "USE ".$self->{name}."\nEXEC SP_SPACEUSED"
    #);
    # server mgmt studio           sp_spaceused
    # Currently Allocated Space    database_size       641.94MB
    # Available Free Space         unallocated space   457.09MB 
    #$database_size =~ s/MB//g;
    #$unallocated_space =~ s/MB//g;
    #$self->{size} = $database_size * 1024 * 1024;
    #$self->{free} = $unallocated_space * 1024 * 1024;
    #$self->{percent_free} = $unallocated_space / $database_size * 100;
    #$self->{used} = $self->{size} - $self->{free};
    #$self->{maxsize} = "99999999999999999";
    ###################################################################################
    my $calc = {};
    if ($params{method} eq 'sqlcmd' || $params{method} eq 'sqsh') {
      foreach($self->{handle}->fetchall_array(q{
        if object_id('tempdb..#FreeSpace') is null
          create table #FreeSpace(
            Drive varchar(10),
            MB_Free bigint
          )
        go
        DELETE FROM tempdb..#FreeSpace
        INSERT INTO tempdb..#FreeSpace exec master.dbo.xp_fixeddrives
        go
        SELECT * FROM tempdb..#FreeSpace
      })) {
        $calc->{drive_mb}->{lc $_->[0]} = $_->[1];
      }
    } else {
      $self->{handle}->execute(q{
        if object_id('tempdb..#FreeSpace') is null 
          create table #FreeSpace(  
            Drive varchar(10),  
            MB_Free bigint  
          ) 
      });
      $self->{handle}->execute(q{
        DELETE FROM #FreeSpace
      });
      $self->{handle}->execute(q{
        INSERT INTO #FreeSpace exec master.dbo.xp_fixeddrives
      });
      foreach($self->{handle}->fetchall_array(q{
        SELECT * FROM #FreeSpace
      })) {
        $calc->{drive_mb}->{lc $_->[0]} = $_->[1];
      }
    }
    #$self->{handle}->execute(q{
    #  DROP TABLE #FreeSpace
    #});
    # Page = 8KB
    # sysfiles ist sv2000, noch als kompatibilitaetsview vorhanden
    # dbo.sysfiles kann 2008 durch sys.database_files ersetzt werden?
    # omeiomeiomei in 2005 ist ein sys.sysindexes compatibility view
    #   fuer 2000.dbo.sysindexes
    #   besser ist sys.allocation_units
    if (DBD::MSSQL::Server::return_first_server()->version_is_minimum("9.x")) {
      my $sql = q{
          SELECT 
              SUM(CAST(used AS BIGINT)) / 128
          FROM 
              [?].sys.sysindexes
          WHERE
              indid IN (0,1,255)
      };
      #$sql =~ s/\[\?\]/$self->{name}/g;
      $sql =~ s/\?/$self->{name}/g;
      $self->{used_mb} = $self->{handle}->fetchrow_array($sql);
    } else {
      my $sql = q{
          SELECT 
              SUM(CAST(used AS BIGINT)) / 128
          FROM 
              [?].dbo.sysindexes
          WHERE
              indid IN (0,1,255)
      };
      #$sql =~ s/\[\?\]/$self->{name}/g;
      $sql =~ s/\?/$self->{name}/g;
      $self->{used_mb} = $self->{handle}->fetchrow_array($sql);
    }
    my @fileresult = ();
    if (DBD::MSSQL::Server::return_first_server()->version_is_minimum("9.x")) {
      my $sql = q{
          SELECT
              RTRIM(a.name), RTRIM(a.filename), CAST(a.size AS BIGINT),
              CAST(a.maxsize AS BIGINT), a.growth
          FROM
              [?].sys.sysfiles a
          JOIN
              [?].sys.sysfilegroups b
          ON
              a.groupid = b.groupid
      };
      #$sql =~ s/\[\?\]/$self->{name}/g;
      $sql =~ s/\?/$self->{name}/g;
      @fileresult = $self->{handle}->fetchall_array($sql);
    } else {
      my $sql = q{
          SELECT
              RTRIM(a.name), RTRIM(a.filename), CAST(a.size AS BIGINT),
              CAST(a.maxsize AS BIGINT), a.growth
          FROM
              [?].dbo.sysfiles a
          JOIN
              [?].dbo.sysfilegroups b
          ON
              a.groupid = b.groupid
      };
      #$sql =~ s/\[\?\]/$self->{name}/g;
      $sql =~ s/\?/$self->{name}/g;
      @fileresult = $self->{handle}->fetchall_array($sql);
    }
    foreach(@fileresult) {
      my($name, $filename, $size, $maxsize, $growth) = @{$_};
      my $drive = lc substr($filename, 0, 1);
      $calc->{datafile}->{$name}->{allocsize} = $size / 128;
      if ($growth == 0) {
        $calc->{datafile}->{$name}->{maxsize} = $size / 128;
      } else {
        if ($maxsize == -1) {
          $calc->{datafile}->{$name}->{maxsize} =
              exists $calc->{drive_mb}->{$drive} ?
                  ($calc->{datafile}->{$name}->{allocsize} + 
                   $calc->{drive_mb}->{$drive}) : 4 * 1024;
          # falls die platte nicht gefunden wurde, dann nimm halt 4GB
          if (exists $calc->{drive_mb}->{$drive}) {
            # davon kann ausgegangen werden. wenn die drives nicht zur
            # vefuegung stehen, stimmt sowieso hinten und vorne nichts.
            $calc->{drive_mb}->{$drive} = 0;
            # damit ist der platz dieses laufwerks verbraten und in
            # max_mb eingeflossen. es darf nicht sein, dass der freie platz
            # mehrfach gezaehlt wird, wenn es mehrere datafiles auf diesem
            # laufwerk gibt.
          }
        } else {
          $calc->{datafile}->{$name}->{maxsize} = $maxsize / 128;
        }
      }
      $self->{allocated_mb} += $calc->{datafile}->{$name}->{allocsize};
      $self->{max_mb} += $calc->{datafile}->{$name}->{maxsize};
    }
    $self->{allocated_mb} = $self->{allocated_mb};
    if ($self->{used_mb} > $self->{allocated_mb}) {
      # obige used-berechnung liefert manchmal (wenns knapp hergeht) mehr als
      # den maximal verfuegbaren platz. vermutlich muessen dann
      # zwecks ermittlung des tatsaechlichen platzverbrauchs 
      # irgendwelche dbcc updateusage laufen.
      # egal, wird schon irgendwie stimmen.
      $self->{used_mb} = $self->{allocated_mb};
      $self->{estimated} = 1;
    } else {
      $self->{estimated} = 0;
    }
    $self->{free_mb} = $self->{max_mb} - $self->{used_mb};
    $self->{free_percent} = 100 * $self->{free_mb} / $self->{max_mb};
    $self->{allocated_percent} = 100 * $self->{allocated_mb} / $self->{max_mb};
  } elsif ($params{mode} =~ /^server::database::transactions/) {
    $self->{transactions_s} = $self->{handle}->get_perf_counter_instance(
        'SQLServer:Databases', 'Transactions/sec', $self->{name});
    if (! defined $self->{transactions_s}) {
      $self->add_nagios_unknown("unable to aquire counter data");
    } else {
      $self->valdiff(\%params, qw(transactions_s));
      $self->{transactions_per_sec} = $self->{delta_transactions_s} / $self->{delta_timestamp};
    }
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if (! $self->{nagios_level}) {
    if ($params{mode} =~ /server::database::datafile::listdatafiles/) {
      foreach (sort { $a->{logicalfilename} cmp $b->{logicalfilename}; }  @{$self->{datafiles}}) {
	printf "%s\n", $_->{logicalfilename};
      }
      $self->add_nagios_ok("have fun");
    } elsif ($params{mode} =~ /^server::database::transactions/) {
      $self->add_nagios(
          $self->check_thresholds($self->{transactions_per_sec}, 10000, 50000),
          sprintf "%s has %.4f transactions / sec",
          $self->{name}, $self->{transactions_per_sec});
      $self->add_perfdata(sprintf "%s_transactions_per_sec=%.4f;%s;%s",
          $self->{name}, $self->{transactions_per_sec},
          $self->{warningrange}, $self->{criticalrange});
    } elsif ($params{mode} =~ /server::database::databasefree/) {
      # ->percent_free
      # ->free
      #
      # ausgabe
      #   perfdata db_<db>_free_pct
      #   perfdata db_<db>_free        (real_bytes_max - bytes) + bytes_free  (with units)
      #   perfdata db_<db>_alloc_free  bytes_free (with units)
      #
              # umrechnen der thresholds
      # ()/%
      # MB
      # GB
      # KB
      if (($self->{warningrange} && $self->{warningrange} !~ /^\d+[\.\d]*:/) ||
          ($self->{criticalrange} && $self->{criticalrange} !~ /^\d+[\.\d]*:/)) {
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
            $self->check_thresholds($self->{free_percent}, "5:", "2:"),
                sprintf("database %s has %.2f%% free space left",
                $self->{name}, $self->{free_percent},
                ($self->{estimated} ? " (estim.)" : ""))
        );
        $self->{warningrange} =~ s/://g;
        $self->{criticalrange} =~ s/://g;
        $self->add_perfdata(sprintf "\'db_%s_free_pct\'=%.2f%%;%d:;%d:",
            lc $self->{name},
            $self->{free_percent},
            $self->{warningrange}, $self->{criticalrange});
        $self->add_perfdata(sprintf "\'db_%s_free\'=%dMB;%.2f:;%.2f:;0;%.2f",
            lc $self->{name},
            $self->{free_mb},
            $self->{warningrange} * $self->{max_mb} / 100,
            $self->{criticalrange} * $self->{max_mb} / 100,
            $self->{max_mb});
        $self->add_perfdata(sprintf "\'db_%s_allocated_pct\'=%.2f%%",
            lc $self->{name},
            $self->{allocated_percent});
      } else {
        my $factor = 1; # default MB
        if ($params{units} eq "GB") {
          $factor = 1024;
        } elsif ($params{units} eq "MB") {
          $factor = 1;
        } elsif ($params{units} eq "KB") {
          $factor = 1 / 1024;
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
        $self->{percent_warning} = 100 * $self->{warningrange} / $self->{max_mb};
        $self->{percent_critical} = 100 * $self->{criticalrange} / $self->{max_mb};
        $self->{warningrange} .= ':';
        $self->{criticalrange} .= ':';
        $self->add_nagios(
            $self->check_thresholds($self->{free_mb}, "5242880:", "1048576:"),
                sprintf("database %s has %.2f%s free space left", $self->{name},
                    $self->{free_mb} / $factor, $params{units})
        );
        $self->{warningrange} = $saved_warningrange;
        $self->{criticalrange} = $saved_criticalrange;
        $self->{warningrange} =~ s/://g;
        $self->{criticalrange} =~ s/://g;
        $self->add_perfdata(sprintf "\'db_%s_free_pct\'=%.2f%%;%.2f:;%.2f:",
            lc $self->{name},
            $self->{free_percent}, $self->{percent_warning},
            $self->{percent_critical});
        $self->add_perfdata(sprintf "\'db_%s_free\'=%.2f%s;%.2f:;%.2f:;0;%.2f",
            lc $self->{name},
            $self->{free_mb} / $factor, $params{units},
            $self->{warningrange},
            $self->{criticalrange},
            $self->{max_mb} / $factor);
        $self->add_perfdata(sprintf "\'db_%s_allocated_pct\'=%.2f%%",
            lc $self->{name},
            $self->{allocated_percent});
      }
    } elsif ($params{mode} =~ /server::database::backupage/) {
      if (! defined $self->{backup_age}) { 
        $self->add_nagios_critical(sprintf "%s was never backupped",
            $self->{name}); 
        $self->{backup_age} = 0;
        $self->{backup_duration} = 0;
        $self->check_thresholds($self->{backup_age}, 48, 72); # init wg perfdata
      } else { 
        $self->add_nagios( 
            $self->check_thresholds($self->{backup_age}, 48, 72), 
            sprintf "%s backupped %dh ago", $self->{name}, $self->{backup_age});
      } 
      $self->add_perfdata(sprintf "'%s_bck_age'=%d;%s;%s", 
          $self->{name}, $self->{backup_age}, 
          $self->{warningrange}, $self->{criticalrange}); 
      $self->add_perfdata(sprintf "'%s_bck_time'=%d", 
          $self->{name}, $self->{backup_duration}); 
    } 
  }
}


1;
