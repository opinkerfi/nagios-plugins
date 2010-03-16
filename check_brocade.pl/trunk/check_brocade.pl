#!/usr/bin/perl -w
#
# Copyright 2010, Tomas Edwardsson 
#
# check_brocade.pl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# check_brocade.pl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Nagios::Plugin;
use Net::SNMP;
use Getopt::Long;
use Data::Dumper;
use vars qw/ %opt /;
use strict;




my $oidbase = "1.3.6.1.4.1.1588.2.1.1.1.1.22";


my %sensorTypes = (
	1 => "temperature",
	2 => "fan",
	3 => "power-supply"
);

my %sensorStatus = (
	1 => "Unknown",
	2 => "Faulty",
	3 => "Below minimum",
	4 => "Nominal",
	5 => "Above maximum",
	6 => "Absent"
);

sub snmp_fetchbase($$$$);

my $np = Nagios::Plugin->new(
	usage => "Usage: %s -H <hostname> -c <snmp_community>",
	version => "0.01",
);


$np->add_arg(
	spec => 'hostname|H=s',
	help => '-H, --hostname=<hostname>',
	required => 1,
);

$np->add_arg(
	spec => 'community|c=s',
	help => '-C, --community=<snmp community>',
	required => 1,
);

$np->add_arg(
	spec => 'snmpversion|n=s',
	help => '-n, --snmpversion=[1/2c]',
	default => '2c',
	required => 0,
);

$np->add_arg(
	spec => 'longserviceoutput|l',
	help => '-l, --longserviceoutput',
	default => undef,
	required => 0,
);

$np->getopts();


my $snmp_sensor_data = snmp_fetchbase( 
	$np->opts->hostname,
	$np->opts->community,
	$np->opts->snmpversion,
	$oidbase);


my %sensordata;
foreach my $k (keys %{$snmp_sensor_data}) {
	my $v = $snmp_sensor_data->{$k};
	$v =~ s/^\s+//g;
	$v =~ s/\s+$//g;
	if ($k =~ /^1\.3\.6\.1\.4\.1\.1588\.2\.1\.1\.1\.1\.22\.1\.(\d+)\.(\d+)$/) {
		$sensordata{$2}->{$1} = $v;
	}
}


$np->add_message( OK, "" ) if ($np->opts->longserviceoutput);
foreach my $sensor (sort keys %sensordata) {
	if ($sensorStatus{$sensordata{$sensor}->{3}} ne "Nominal") {
		$np->add_message( CRITICAL, "$sensordata{$sensor}->{5} is $sensorStatus{$sensordata{$sensor}->{3}}");
	} else {
		$np->add_message( OK, "$sensordata{$sensor}->{5} is $sensorStatus{$sensordata{$sensor}->{3}}");
	}

	if ($sensorTypes{$sensordata{$sensor}->{2}} eq "temperature") {
		$np->add_perfdata(
			label => $sensordata{$sensor}->{5},
			value => $sensordata{$sensor}->{4},
			uom => "Celsius");
	} elsif ($sensorTypes{$sensordata{$sensor}->{2}} eq "fan") {
		$np->add_perfdata(
			label => $sensordata{$sensor}->{5},
			value => $sensordata{$sensor}->{4},
			uom => "RPM");
	}
	#printf("Type: %-14s Name: %-22s Status: %-12s Value: %i\n",
		#$sensorTypes{$sensordata{$sensor}->{2}},
		#$sensordata{$sensor}->{5},
		#$sensorStatus{$sensordata{$sensor}->{3}},
		#$sensordata{$sensor}->{4});
}


my ($code, $message) = $np->check_messages("join" => ($np->opts->longserviceoutput ? "\n" : ""));
$np->nagios_exit( $code, $message );

sub snmp_fetchbase($$$$) {
	my $host = shift;
	my $community = shift;
	my $version = shift;
	my $oidbase = shift;
	
	my ($session, $error) = Net::SNMP->session(
		-hostname  => $host,
		-community => $community,
		-version   => $version,
		-port      => "161"
                                         );
	$np->nagios_exit(CRITICAL, "Unable to connect to snmp host, $error") if ($error);
	my $response = $session->get_table(-baseoid => $oidbase);

	my $err = $session->error;
	$np->nagios_exit(CRITICAL, "Unable to retrieve snmp data, $err") if ($err);

	return $response;
}


