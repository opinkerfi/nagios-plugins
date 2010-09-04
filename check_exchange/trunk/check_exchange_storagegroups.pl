#!/usr/bin/perl 
#
# Copyright 2010, Pall Sigurdsson <palli@opensource.is>
#
# check_exchange.pl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# check_exchange.pl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This script will check Active Client Logons for every storagegroup in exchange of a given host (via NRPE)
# Useful to find dismounted storagegroups
# Author Pall Sigurdsson <palli@opensource.is>
#

$HOSTNAME=$ARGV[0];
$OK=0;
$WARNING=1;
$CRITICAL=2;
$UNKNOWN=3;
$EXIT_CODE=$UNKNOWN;

$counter="MSExchangeIS Mailbox";
$field="Client Logons";

#$result = `/usr/lib/nagios/plugins/check_nrpe -H $HOSTNAME -c listCounterInstances -a $counter`;
#$result="NL-AMERICA-02, NL-AFRICA-01, NL-AMERICA-03, Mailbox Database 0898192844, NL-AUSTRALASIA-02, IS-ICELAND-03, IS-ICELAND-01, NL-EAST-EUROPE-02, NL-EAST-EUROPE-01, IS-ICELAND-05, IS-ICELAND-02, IS-ICELAND-04, NL-AUSTRALASIA-01, NL-AMERICA-01, IS-ICELAND-06, NL-WEST-EUROPE-02, NL-WEST-EUROPE-01, IS-ICELAND-07, NL-WEST-EUROPE-03, _Total";
$result=$ARGV[1];

@instances = split(/\,/, $result);
@instances = sort(@instances);
@warning_instances =();

$minwarn=1;
$longserviceoutput="";
$summary="";

#[root@nagios ~]# check_nrpe -H $HOSTNAME -c CheckCounter -a "Counter:Vanskilaskra=\SQLServer:Databases(Vanskilaskra)\Data File(s) Size (KB)"# OK all counters within bounds.|'Vanskilaskra'=30996480;0;0; 
$num_items = 0;
$perfdata = "";
foreach $item (@instances)
{
        # Strip whitespace
        $item =~ s/^\s*(.*?)\s*$/$1/;

        # Call check_nrpe
        $result = `/usr/lib/nagios/plugins/check_nrpe -H $HOSTNAME -c CheckCounter -a 'Counter:$item=\\$counter($item)\\$field' MinWarn=$minwarn ShowAll`;
	push(@warning_instances,$item) if $? > 0;

        # Strip everything but the performance data
        $result =~ /^(.*)\|(.*?)$/;
	$current_perfdata = $2;
	$current_result = $1;
        chomp($current_perfdata);
	$longserviceoutput = $longserviceoutput . $current_result . "\n";
        $perfdata = $perfdata . " " . $current_perfdata;
        $num_databases = $num_databases + 1;


}

$num_instances=scalar(@instances);
$summary="$num_instances databases found in $HOSTNAME";
$EXIT_CODE=$OK;
if (scalar(@warning_instances) > 0) {
	$summary= "$summary (check @warning_instances)";
	$EXIT_CODE=$WARNING;
}

print "$summary | $perfdata \n";
print $longserviceoutput;
exit $EXIT_CODE;

