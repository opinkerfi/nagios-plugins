#!/usr/bin/perl 
#
# This script will check MSSQL Database size via check_nrpe and NSclient. returns performance data in Nagios format
# Author Pall Sigurdsson <palli@opensource.is>
#

$HOSTNAME=$ARGV[0];


$databases = `check_nrpe -H $HOSTNAME -c listCounterInstances -a "SQLServer:Databases"`;
@array1 = split(/\,/, $databases);


#[root@nagios ~]# check_nrpe -H $HOSTNAME -c CheckCounter -a "Counter:Vanskilaskra=\SQLServer:Databases(Vanskilaskra)\Data File(s) Size (KB)"# OK all counters within bounds.|'Vanskilaskra'=30996480;0;0; 
$num_databases = 0;
$perfdata = "";
foreach $database (@array1)
{
	# Strip whitespace
	$database =~ s/^\s*(.*?)\s*$/$1/;

	# Call check_nrpe
	$dbSize = `check_nrpe -H $HOSTNAME -c CheckCounter -a 'Counter:$database=\\SQLServer:Databases($database)\\Data File(s) Size (KB)'`;

	# Strip everything but the performance data
	$dbSize =~ s/^.*\|(.*?)$/$1/;
	chomp($dbSize);
	$perfdata = $perfdata . " " . $dbSize;
	$num_databases = $num_databases + 1;


}

print "$num_databases databases found | $perfdata \n";
