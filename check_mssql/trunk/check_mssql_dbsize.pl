#!/usr/bin/perl -w
#
# This script will check MSSQL Database size via check_nrpe and NSclient. returns performance data in Nagios format
# Author Pall Sigurdsson <palli@opensource.is>
#

use strict;
use Nagios::Plugin;


my $np = Nagios::Plugin->new(
	usage => "Usage: %s <hostname>" );

$np->add_arg(
	spec => 'debug|d=i',
	help => '-d, --debug=INTEGER',
);

$np->getopts;

my $NRPECMD = "/usr/lib/nagios/plugins/check_nrpe";

if (@ARGV < 1) {
	usage();
	exit 3;
}

my $HOSTNAME=$ARGV[0];


my $databases = nrpeexec("-H $HOSTNAME -t 60 -c listCounterInstances -a 'SQLServer:Databases'");
my @array1 = split(/\,/, $databases);


my $num_databases = 0;
foreach my $database (@array1)
{
	# Strip whitespace
	$database =~ s/^\s*(.*?)\s*$/$1/;

	# Call check_nrpe
	my $dbSize = nrpeexec("-H $HOSTNAME -t 60 -c CheckCounter -a 'Counter:$database=\\SQLServer:Databases($database)\\Data File(s) Size (KB)'");

	# Strip everything but the performance data
	$dbSize =~ s/^.*\|(.*?)$/$1/;
	chomp($dbSize);
	$np->add_perfdata($dbSize);
	$num_databases = $num_databases + 1;
}

$np->nagios_exit( OK, "$num_databases databases found in $HOSTNAME");



sub usage {
	print <<"	EOUSAGE";
Usage $0 <hostname>
	EOUSAGE
}



# Execute NRPE with some error handling
sub nrpeexec {
	my @args = @_;

	my $output = '';
	if (open NRPE, "$NRPECMD " . join(' ',@args) . ' 2>&1 |') {
		$output .= $_ while(<NRPE>);
		close NRPE;
	}
	my $ret = $? >> 8;
	# No such file or directory
	if ($ret == 127) {
		$np->nagios_die("Cannot execute $NRPECMD command missing");
	# Some other error
	} elsif ($ret != 0) {
		$np->nagios_die("Cannot execute $NRPECMD: $!");
	}
	return $output;
}
