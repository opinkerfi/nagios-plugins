#! /usr/bin/perl -w -I ..
#
# MySQL Database Server Tests via check_oracle_healthdb
#
#
# These are the database permissions required for this test:
#  GRANT SELECT ON $db.* TO $user@$host INDENTIFIED BY '$password';
#  GRANT SUPER, REPLICATION CLIENT ON *.* TO $user@$host;
# Check with:
	#  mysql -u$user -p$password -h$host $db

use strict;
use Test::More;
use NPTest;

use vars qw($tests);

plan skip_all => "check_oracle_health not compiled" unless (-x "check_oracle_health");

plan tests => 51;

my $bad_login_output = '/Access denied for user /';
my $oracle_dsn = getTestParameter( 
		"ORACLE_DSN", 
		"Command line parameters to specify login access",
		"bba"
		);

my $oracle_user = getTestParameter( 
		"ORACLE_USER", 
		"Command line parameters to specify login access",
		"nagios"
		);

my $oracle_pass = getTestParameter( 
		"ORACLE_PASS", 
		"Command line parameters to specify login access",
		"oradbmon"
		);

my $oracle_method = getTestParameter( 
		"ORACLE_METHOD", 
		"Command line parameters to specify login access",
		"tns"
		);

my $login = {
  'ora9' => {
    'tns' => ' --connect=ora9 --user=system --password=consol --method=tns ', 
    'sqlplus' => ' --connect=ora9 --user=system --password=consol --method=sqlplus ', 
  },
  'ora10' => {
    'tns' => ' --connect=ora10 --user=system --password=consol --method=tns ', 
    'sqlplus' => ' --connect=ora10 --user=system --password=consol --method=sqlplus ', 
  },
  'bba' => {
    'tns' => ' --connect=bba --user=nagios --password=oradbmon --method=tns ',
    'sqlplus' => ' --connect=bba --user=nagios --password=oradbmon --method=sqlplus ',
  },
};

my $oracle_login_details = $login->{$oracle_dsn}->{$oracle_method};


my $result;
SKIP: {
	$result = NPTest->testCmd("./check_oracle_health -V");
	cmp_ok( $result->return_code, '==', 0, "expected result");
	like( $result->output, '/check_oracle_health \(\d+[\.\d]+\)/', "Expected message for -V");

	$result = NPTest->testCmd("./check_oracle_health --help");
	cmp_ok( $result->return_code, '==', 0, "expected result");
	like( $result->output, "/connection-time/", "Expected message");
	like( $result->output, "/sga-data-buffer-hit-ratio/", "Expected message");
	like( $result->output, "/pga-in-memory-sort-ratio/", "Expected message");
}

SKIP: {
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=tnsping");
	cmp_ok( $result->return_code, '==', 0, "connect ok");
	like( $result->output, "/OK - connection established/", "Expected output tnsping");

	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=connection-time --warning=10 --critical=20");
	cmp_ok( $result->return_code, '==', 0, "connect ok");
	like( $result->output, "/OK - (\\d+\\.\\d+) seconds to connect | connection_time=(\\d+\\.\\d+);1;5/", "Expected output connection-time");
	diag("./check_oracle_health $oracle_login_details --mode=connection-time");

	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=connected-users");
	cmp_ok( $result->return_code, '==', 0, "connect ok");
        like( $result->output, "/OK - ([0-9]+) connected users | connected_users=([0-9]+);1;5/", "Expected output connected-users");
	$result->output =~ /([0-9]+) connected users \| connected_users=([0-9]+);50;100/;
	ok($1 == $2);
	diag($result->output);
}

SKIP: {
 # caches 
  diag("buffer cache");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-data-buffer-hit-ratio");
	like( $result->output, "/SGA data buffer hit ratio ([\.0-9]+)% .* sga_data_buffer_hit_ratio=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+)/", "Expected message cache hits");
	$result->output =~ /SGA data buffer hit ratio ([\.0-9]+)% .* sga_data_buffer_hit_ratio=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
	my $value = $1; my $pvalue = $2; my $warn = $3; my $crit = $4;
	my $expec = 0;
	$expec = 1 if $value < $warn;
	$expec = 2 if $value < $crit;
	cmp_ok( $value, '==', $pvalue);
	cmp_ok( $result->return_code, '==', $expec, "exitcode ok");

	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-data-buffer-hit-ratio --warning=80: --critical=50:");
	like( $result->output, "/SGA data buffer hit ratio ([\.0-9]+)% .* sga_data_buffer_hit_ratio=([\.0-9]+)%;80:;50:/", "Expected message own cache hits");
	$result->output =~ /SGA data buffer hit ratio ([\.0-9]+)% .* sga_data_buffer_hit_ratio=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
	$expec = 1 if $value < $warn;
	$expec = 2 if $value < $crit;
	cmp_ok( $value, '==', $pvalue);
	cmp_ok( $result->return_code, '==', $expec, "exitcode ok");
	diag($result->output);

  diag("library cache");
 # library cache 
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-library-cache-hit-ratio");
        like( $result->output, "/SGA library cache hit ratio ([\.0-9]+)% .* sga_library_cache_hit_ratio=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+)/", "Expected message libcache hits");
        $result->output =~ /SGA library cache hit ratio ([\.0-9]+)% .* sga_library_cache_hit_ratio=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value < $warn;
        $expec = 2 if $value < $crit;
	cmp_ok( $value, '==', $pvalue);
        cmp_ok( $result->return_code, '==', $expec, "exitcode ok");

        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-library-cache-hit-ratio --warning=80: --critical=50:");
        like( $result->output, "/SGA library cache hit ratio ([\.0-9]+)% .* sga_library_cache_hit_ratio=([\.0-9]+)%;80:;50:/", "Expected message own libcache hits");
        $result->output =~ /SGA library cache hit ratio ([\.0-9]+)% .* sga_library_cache_hit_ratio=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value < $warn;
        $expec = 2 if $value < $crit;
	cmp_ok( $value, '==', $pvalue);
        cmp_ok( $result->return_code, '==', $expec, "exitcode ok");
	diag($result->output);


  diag("dictionary cache");
 # dictionary cache 
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-dictionary-cache-hit-ratio");
        like( $result->output, "/SGA dictionary cache hit ratio ([\.0-9]+)% .* sga_dictionary_cache_hit_ratio=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+)/", "Expected message dictcache hits");
        $result->output =~ /SGA dictionary cache hit ratio ([\.0-9]+)% .* sga_dictionary_cache_hit_ratio=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value < $warn;
        $expec = 2 if $value < $crit;
	cmp_ok( $value, '==', $pvalue);
        cmp_ok( $result->return_code, '==', $expec, "exitcode ok");

        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-dictionary-cache-hit-ratio --warning=80: --critical=50:");
        like( $result->output, "/SGA dictionary cache hit ratio ([\.0-9]+)% .* sga_dictionary_cache_hit_ratio=([\.0-9]+)%;80:;50:/", "Expected message own dictcache hits");
        $result->output =~ /SGA dictionary cache hit ratio ([\.0-9]+)% .* sga_dictionary_cache_hit_ratio=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value < $warn;
        $expec = 2 if $value < $crit;
	cmp_ok( $value, '==', $pvalue);
        cmp_ok( $result->return_code, '==', $expec, "exitcode ok");
	diag($result->output);

  diag("latches");
 # latches
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-latches-hit-ratio");
        like( $result->output, "/SGA latches hit ratio ([\.0-9]+)% .* sga_latches_hit_ratio=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+)/", "Expected message latch hits");
        $result->output =~ /SGA latches hit ratio ([\.0-9]+)% .* sga_latches_hit_ratio=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value < $warn;
        $expec = 2 if $value < $crit;
	cmp_ok( $value, '==', $pvalue);
        cmp_ok( $result->return_code, '==', $expec, "exitcode ok");

        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-latches-hit-ratio --warning=85: --critical=55:");
        like( $result->output, "/SGA latches hit ratio ([\.0-9]+)% .* sga_latches_hit_ratio=([\.0-9]+)%;98:;95:/", "Expected message latches");
        $result->output =~ /SGA latches hit ratio ([\.0-9]+)% .* sga_latches_hit_ratio=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value < $warn;
        $expec = 2 if $value < $crit;
	diag($result->output);

  diag("reloads");
diag("./check_oracle_health $oracle_login_details --mode=sga-shared-pool-reloads");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-shared-pool-reloads");
        like( $result->output, "/SGA shared pool reload ratio ([\.0-9]+)% .* sga_shared_pool_reload_ratio=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+)/", "Expected message reloads");
        $result->output =~ /SGA shared pool reload ratio ([\.0-9]+)% .* sga_shared_pool_reload_ratio=([\.0-9]+)%;([\.0-9]+);([\.0-9]+)/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value > $warn;
        $expec = 2 if $value > $crit;
	cmp_ok( $value, '==', $pvalue);
        cmp_ok( $result->return_code, '==', $expec, "exitcode ok");

        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-shared-pool-reload-ratio --warning=10 --critical=12");
        like( $result->output, "/SGA shared pool reload ratio ([\.0-9]+)% .* sga_shared_pool_reload_ratio=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+)/", "Expected message reloads");
        $result->output =~ /SGA shared pool reload ratio ([\.0-9]+)% .* sga_shared_pool_reload_ratio=([\.0-9]+)%;([\.0-9]+);([\.0-9]+)/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value > $warn;
        $expec = 2 if $value > $crit;
	diag($result->output);
  	ok($warn == 10 && $crit == 12);
        cmp_ok( $result->return_code, '==', $expec, "exitcode ok");
	diag($result->output);

  diag("free");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-shared-pool-free");
        like( $result->output, "/SGA shared pool free ([\.0-9]+)% .* sga_shared_pool_free=([\.0-9]+)%;([\.0-9:]+):;([\.0-9:]+):/", "Expected message reloads");
        $result->output =~ /SGA shared pool free ([\.0-9]+)% .* sga_shared_pool_free=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value < $warn;
        $expec = 2 if $value < $crit;
        cmp_ok( $value, '==', $pvalue);
        cmp_ok( $result->return_code, '==', $expec, "exitcode ok");

        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sga-shared-pool-free --warning=5: --critical=1:");
        like( $result->output, "/SGA shared pool free ([\.0-9]+)% .* sga_shared_pool_free=([\.0-9]+)%;([\.0-9:]+):;([\.0-9:]+):/", "Expected message free");
        $result->output =~ /SGA shared pool free ([\.0-9]+)% .* sga_shared_pool_free=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+):/;
        $value = $1; $pvalue = $2; $warn = $3; $crit = $4;
        $expec = 0;
        $expec = 1 if $value < $warn;
        $expec = 2 if $value < $crit;
        ok($value == $pvalue);
        ok($warn == 5 && $crit == 1);
	cmp_ok( $result->return_code, '==', $expec, "exitcode ok");
	diag($result->output);

}

SKIP: {
  diag("inmemsort");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=pga-in-memory-sort-ratio");
        like( $result->output, "/PGA in-memory sort ratio [0-9\.]+% \| pga_in_memory_sort_ratio=[0-9\.]+%;99:;90:/", "Expected inmemsort");
        $result->output =~ /PGA in-memory sort ratio ([0-9\.]+)% \| pga_in_memory_sort_ratio=([0-9\.]+)%;99:;90:/;
        ok($1 == $2);
	diag($result->output);
}

SKIP: {
  diag("top10");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=seg-top10-logical-reads");
        like( $result->output, "/[0-9]+ user processes among the top10 logical reads \| users_among_top10_logical_reads=[0-9]+;1;9/", "Expected top 10");
        $result->output =~ /([0-9]+) user processes among the top10 logical reads \| users_among_top10_logical_reads=([0-9]+);1;9/;
        ok($1 == $2);
	diag($result->output);
}

SKIP: {
  diag("invalid objects");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=invalid-objects");
diag("./check_oracle_health $oracle_login_details --mode=invalid-objects");
        like( $result->output, "/(no invalid objects)|([0-9]+ invalid objects)/", "Expected no invalid objects");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=stale-statistics");
        like( $result->output, "/([0-9]+) objects with stale statistics .* stale_stats_objects=([0-9]+);10;100/", "Expected no stale objects");
        $result->output =~ /([0-9]+) objects with stale statistics .* stale_stats_objects=([0-9]+);10;100/;
        ok($1 == $2);
	diag($result->output);
}

SKIP: {
  diag("tablespace usage");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=tablespace-usage");
        like( $result->output, '/tbs (\w+) usage is ([\.0-9]+)%, tbs (\w+) usage is ([\.0-9]+)%, .* \'tbs_(\w+)_usage_pct\'=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+) \'tbs_(\w+)_usage\'=(\d+)MB;\d+;\d+;0;\d+ \'tbs_users_alloc\'=(\d+)MB;;;0;(\d+) \'tbs_(\w+)_usage_pct\'=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+) \'tbs_(\w+)_usage\'=(\d+)MB;\d+;\d+;0;\d+ \'tbs_(\w+)_alloc\'=(\d+)MB;;;0;(\d+)/', "Expected message tbs usage");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=tablespace-usage --tablespace=USERS");
        like( $result->output, '/tbs USERS usage is ([\.0-9]+)% \| \'tbs_users_usage_pct\'=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+) \'tbs_users_usage\'=(\d+)MB;\d+;\d+;0;\d+ \'tbs_users_alloc\'=(\d+)MB;;;0;(\d+)$/', "Expected message tbs usage");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=tablespace-usage --name=USERS");
        like( $result->output, '/tbs USERS usage is ([\.0-9]+)% \| \'tbs_users_usage_pct\'=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+) \'tbs_users_usage\'=(\d+)MB;\d+;\d+;0;\d+ \'tbs_users_alloc\'=(\d+)MB;;;0;(\d+)$/', "Expected message tbs usage");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=tablespace-usage --name=users");
        like( $result->output, '/tbs USERS usage is ([\.0-9]+)% \| \'tbs_users_usage_pct\'=([\.0-9]+)%;([\.0-9:]+);([\.0-9:]+) \'tbs_users_usage\'=(\d+)MB;\d+;\d+;0;\d+ \'tbs_users_alloc\'=(\d+)MB;;;0;(\d+)$/', "Expected message tbs usage");
	diag($result->output);
  
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=tablespace-fragmentation --name=users");
        like( $result->output, '/tbs USERS fsfi is ([\.0-9]+) \| \'tbs_users_fsfi\'=([\.0-9]+);([\.0-9:]+);([\.0-9:]+);0;100$/', "Expected message tbs frag");
}

SKIP: {
  diag("tablespace free");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=tablespace-free --name=SYSTEM");
        like( $result->output, '/tbs SYSTEM has ([\.0-9]+)% free space left .* \'tbs_system_free_pct\'=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+): \'tbs_system_free\'=([\.0-9]+)MB;([\.0-9]+):;([\.0-9]+):;0;([\.0-9]+)/');
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=tablespace-free --name=SYSTEM --units=KB");
        like( $result->output, '/tbs SYSTEM has ([\.0-9]+)KB free space left .* \'tbs_system_free_pct\'=([\.0-9]+)%;([\.0-9]+):;([\.0-9]+): \'tbs_system_free\'=([\.0-9]+)KB;([\.0-9]+):;([\.0-9]+):;0;([\.0-9]+)/');
}

SKIP: {
  diag ("parser");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=soft-parse-ratio");
        like( $result->output, '/Soft parse ratio ([\.0-9]+)% \| soft_parse_ratio=([\.0-9]+)%;(\d+):;(\d+):/', "Expected ratio");
        $result->output =~ /Soft parse ratio ([\.0-9]+)% \| soft_parse_ratio=([\.0-9]+)%;(\d+):;(\d+):/;
	my $ratio = $1; my $pratio = $2; my $warn = $3; my $crit = $4;
	ok($ratio == $pratio);
	ok($warn == 98 && $crit == 90);

        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=soft-parse-ratio --warning=80: --critical=50:");
        like( $result->output, '/Soft parse ratio ([\.0-9]+)% \| soft_parse_ratio=([\.0-9]+)%;(\d+):;(\d+):/', "Expected ratio");
        $result->output =~ /Soft parse ratio ([\.0-9]+)% \| soft_parse_ratio=([\.0-9]+)%;(\d+):;(\d+):/;
	$ratio = $1; $pratio = $2; $warn = $3; $crit = $4;
	ok($ratio == $pratio);
	ok($warn == 80 && $crit == 50);
	diag($result->output);

}

SKIP: {
  diag("redo log switch interval");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=switch-interval");
        like( $result->output, '/(OK|WARNING|CRITICAL) - Last redo log file switch interval was (\d+) minutes \| redo_log_file_switch_interval=(\d+)s;(\d+):;(\d+):/', "expected interval");
        $result->output =~ / Last redo log file switch interval was (\d+) minutes \| redo_log_file_switch_interval=(\d+)s;(\d+):;(\d+):/;
	my $ratio = $1; my $pratio = $2; my $warn = $3; my $crit = $4;
	ok($ratio == int($pratio / 60));
	ok($warn == 600 && $crit == 60);

        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=switch-interval --warning=1000: --critical=10:");
        like( $result->output, '/(OK|WARNING|CRITICAL) - Last redo log file switch interval was (\d+) minutes \| redo_log_file_switch_interval=(\d+)s;1000:;10:/', "expected interval with threshold");
        $result->output =~ /OK - Last redo log file switch interval was (\d+) minutes \| redo_log_file_switch_interval=(\d+)s;(\d+):;(\d+):/;
	$ratio = $1; $pratio = $2; $warn = $3; $crit = $4;
	ok($ratio  == int($pratio / 60));
	ok($warn == 1000 && $crit == 10);
	diag($result->output);
}

SKIP: {
  diag("retry ratio");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=retry-ratio");
        like( $result->output, '/Redo log retry ratio is ([0-9\.]+)% \| redo_log_retry_ratio=([\d\.]+)%;1;10/', "expected ratio");
        $result->output =~ /Redo log retry ratio is ([0-9\.]+)% \| redo_log_retry_ratio=([\d\.]+)%;1;10/;
        my $ratio = $1; my $pratio = $2; my $warn = $3; my $crit = $4;
        ok($ratio == $pratio);

        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=retry-ratio --warning=2 --critical=20");
        like( $result->output, '/Redo log retry ratio is ([0-9\.]+)% \| redo_log_retry_ratio=([\d\.]+)%;(\d+);(\d+)/', "expected ratio");
        $result->output =~ /Redo log retry ratio is ([0-9\.]+)% \| redo_log_retry_ratio=([\d\.]+)%;(\d+);(\d+)/;
        $ratio = $1; $pratio = $2; $warn = $3; $crit = $4;
        ok($ratio == $pratio);
	ok($warn == 2 && $crit == 20);
	diag($result->output);
}

SKIP: {
  diag("redo io");
        $result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=redo-io-traffic --warning=101 --critical=201");
diag($result->output);
        like( $result->output, '/Redo log io is ([0-9\.]+) MB\/sec \| redo_log_io_per_sec=([0-9\.]+);101;201/', "expected traffic");
        $result->output =~ /Redo log io is ([0-9\.]+) MB\/sec \| redo_log_io_per_sec=([0-9\.]+);([0-9\.]+);([0-9\.]+)/;
        my $io = $1; my $pio = $2; my $warn = $3; my $crit = $4;
printf "io %s pio %s\n", $io, $pio;
        ok($io == $pio);
	diag($result->output);
}


SKIP: {
  diag ("rollback segments");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=roll-header-contention");
        like( $result->output, '/Rollback segment header contention is ([0-9\.]+)% \| rollback_segment_header_contention=([\d\.]+)%;1;2/', "expected contention");
        $result->output =~ /Rollback segment header contention is ([0-9\.]+)% \| rollback_segment_header_contention=([\d\.]+)%;1;2/;
        my $cont = $1; my $pcont = $2; my $warn = $3; my $crit = $4;
        ok(sprintf("%.2f", $cont) == $pcont);

	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=roll-header-contention --warning=5 --critical=25");
        like( $result->output, '/Rollback segment header contention is ([0-9\.]+)% \| rollback_segment_header_contention=([\d\.]+)%;5;25/', "expected contention");
        $result->output =~ /Rollback segment header contention is ([0-9\.]+)% \| rollback_segment_header_contention=([\d\.]+)%;(\d+);(\d+)/;
        $cont = $1; $pcont = $2; $warn = $3; $crit = $4;
        ok(sprintf("%.2f", $cont) == $pcont);
	ok($warn == 5 && $crit == 25);
	diag($result->output);
}

SKIP: {
  diag ("datafile io");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=datafile-io-traffic --datafile=system01.dbf --critical=3000");
        like( $result->output, '/system01.dbf: ([\d\.]+) IO Operations per Second \| \'dbf_system01.dbf_io_total_per_sec\'=([\d\.]+);1000;3000/');
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=datafile-io-traffic --name=system01.dbf --critical=3000");
        like( $result->output, '/system01.dbf: ([\d\.]+) IO Operations per Second \| \'dbf_system01.dbf_io_total_per_sec\'=([\d\.]+);1000;3000/');
	$result->output =~ /system01.dbf: ([\d\.]+) IO Operations per Second \| 'dbf_system01.dbf_io_total_per_sec'=([\d\.]+);1000;3000/;
	diag($result->output);
	ok($1 == $2);
}

SKIP: {
  diag("latches");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=latch-contention --name=1");
        like( $result->output, '/SGA (.*?) \(#1\) contention [0-9\.]+% \| \'latch_1_contention\'=[0-9\.]+%;1;2 \'latch_1_gets\'=[0-9]+/');
	$result->output =~ /SGA (.*?) \(#1\) contention ([\d\.]+)% \| 'latch_1_contention\'=([\d\.]+)%;1;2 \'latch_1_gets\'=\d+/;
	ok($2 eq $3);
	diag($result->output);
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=latch-waiting --name=1");
        like( $result->output, '/SGA (.*?) \(#1\) sleeping [0-9\.]+% of the time \| \'latch_1_sleep_share\'=[0-9\.]+%;0.1;1;0;100/');
	$result->output =~ /SGA (.*?) \(#1\) sleeping ([\d\.]+)% of the time \| \'latch_1_sleep_share\'=([\d\.]+)%;0.1;1;0;100/;
	ok($2 eq $3);
	diag($result->output);
}

SKIP: {
  diag("events");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=event-waits --name='log file sync'");
        like( $result->output, '/log file sync : ([\d\.]+) waits\/sec \| \'log file sync_waits_per_sec\'=([\d\.]+);10;100/');
	$result->output =~ /log file sync : ([\d\.]+) waits\/sec \| \'log file sync_waits_per_sec\'=([\d\.]+);10;100/;
	ok($1 eq $2);
	diag($result->output);
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=event-waiting --name='log file sync'");
        like( $result->output, '/log file sync waits ([\d\.]+)% of the time \| \'log file sync_percent_waited\'=([\d\.]+)%;0.1;0.5/');
	$result->output =~ /log file sync waits ([\d\.]+)% of the time \| \'log file sync_percent_waited\'=([\d\.]+)%;0.1;0.5/;
	ok($1 eq $2);
	diag($result->output);
}

SKIP: {
  diag("enqueues");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=enqueue-contention --name=HW");
        like( $result->output, '/enqueue HW High-Water Lock: ([\d\.]+)% of the requests must wait  \| \'HW_contention\'=([\d\.]+)%;1;10 \'HW_requests\'=([\d]+) \'HW_waits\'=([\d]+)/');
	$result->output =~ /enqueue HW High-Water Lock: ([\d\.]+)% of the requests must wait  \| \'HW_contention\'=([\d\.]+)%;1;10 \'HW_requests\'=([\d]+) \'HW_waits\'=([\d]+)/;
	ok($1 eq $2);
	diag($result->output);
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=enqueue-waiting --name=HW");
        like( $result->output, '/enqueue HW High-Water Lock: waiting ([\d\.]+)% of the time \| \'HW_ms_waited\'=([\d]+) \'HW_pct_waited\'=([\d\.]+)%;0.0003333;0.003333/');
	$result->output =~ /enqueue HW High-Water Lock: waiting ([\d\.]+)% of the time \| \'HW_ms_waited\'=([\d]+) \'HW_pct_waited\'=([\d\.]+)%;0.0003333;0.003333/;
	ok($3 == $1);
	diag($result->output);
}

SKIP: {
  diag("systats");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sysstat --name='sorts (memory)' --warning=12 --critical=15");
        like( $result->output, '/([\d\.]+) sorts \(memory\)\/sec \| \'sorts \(memory\)_per_sec\'=([\d\.]+);12;15 \'sorts \(memory\)\'=([\d]+)/');
	$result->output =~ /([\d\.]+) sorts \(memory\)\/sec \| \'sorts \(memory\)_per_sec\'=([\d\.]+);12;15 \'sorts \(memory\)\'=([\d]+)/;
	ok($1 eq $2);
	diag($result->output);
}

SKIP: {
  diag ("generic sql");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sql --name='select count(*) from v\$latch'");
        like( $result->output, '/CRITICAL - select count\(\*\) from v\$latch: ([\d]+) \| \'select count\(\*\) from v\$latch\'=([\d]+);1;5/');
        $result->output =~ /CRITICAL - select count\(\*\) from v\$latch: ([\d]+) \| 'select count\(\*\) from v\$latch'=([\d]+);1;5/;
	ok($1 == $2);
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sql --name='select count(*) from v\$latch' --name2='so a kaas'");
        like( $result->output, '/CRITICAL - so a kaas: ([\d]+) \| \'so a kaas\'=([\d]+);1;5/');
        $result->output =~ /CRITICAL - so a kaas: ([\d]+) \| 'so a kaas'=([\d]+);1;5/;
	ok($1 == $2);
	diag($result->output);

	my $hash = NPTest->testCmd("echo 'select 4/3 from dual' | ./check_oracle_health $oracle_login_details --mode=encode")->output;
	ok($hash eq "select%204%2F3%20from%20dual");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sql --name=$hash --name2=calc");
	my $match = 'WARNING \- calc\: 1\.33 | \'calc\'=1\.33;1;5';
	like( $result->output, '/'.$match.'/');
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sql --name=$hash --name2=calc --units=B");
	$match = 'WARNING \- calc\: 1\.33B | \'calc\'=1\.33B;1;5';
	like( $result->output, '/'.$match.'/');
	
	$hash = NPTest->testCmd("echo 'select 4/2 from dual' | ./check_oracle_health $oracle_login_details --mode=encode")->output;
	ok($hash eq "select%204%2F2%20from%20dual");
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sql --name=$hash --name2=calc");
	$match = 'WARNING \- calc\: 2 | \'calc\'=2;1;5';
	like( $result->output, '/'.$match.'/');
	$result = NPTest->testCmd("./check_oracle_health $oracle_login_details --mode=sql --name=$hash --name2=calc --units=B");
	$match = 'WARNING \- calc\: 2B | \'calc\'=2B;1;5';
	like( $result->output, '/'.$match.'/');
	
}





















