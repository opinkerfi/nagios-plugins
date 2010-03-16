#!/usr/bin/perl -w
#
# Copyright 2010, Tomas Edwardsson 
#
# check_brocade_env.pl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# check_brocade_env.pl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Nagios::Plugin;
use Net::SNMP;
use strict;


# OID Base for Sensor Data
my $oidbase = "1.3.6.1.4.1.1588.2.1.1.1.1.22";


# Friendly type names for sensors
my %sensorTypes = (
	1 => "temperature",
	2 => "fan",
	3 => "power-supply"
);

# Friendly status names for sensors
my %sensorStatus = (
	1 => "Unknown",
	2 => "Faulty",
	3 => "Below minimum",
	4 => "Nominal",
	5 => "Above maximum",
	6 => "Absent"
);

sub snmp_fetchbase($$$$);

# Create the Nagios plugin object
my $np = Nagios::Plugin->new(
	usage => "Usage: %s -H <hostname> -c <snmp_community>",
	version => "0.01",
);


# Add valid arguments
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

# Parse Arguments
$np->getopts();


# Fetch the snmp data from the switch
my $snmp_sensor_data = snmp_fetchbase( 
	$np->opts->hostname,
	$np->opts->community,
	$np->opts->snmpversion,
	$oidbase);


# Re-format snmp sensor data to easily parsable for the plugin
my %sensordata;
foreach my $k (keys %{$snmp_sensor_data}) {
	# Remove spaces from front/end
	my $v = $snmp_sensor_data->{$k};
	$v =~ s/^\s+//g;
	$v =~ s/\s+$//g;

	if ($k =~ /^1\.3\.6\.1\.4\.1\.1588\.2\.1\.1\.1\.1\.22\.1\.(\d+)\.(\d+)$/) {
		$sensordata{$2}->{$1} = $v;
	}
}


# Hack for multiline status output
$np->add_message( OK, "" ) if ($np->opts->longserviceoutput);

# Loop through each installed sensor
foreach my $sensor (sort keys %sensordata) {
	my $label = "";

	# Add the performance data
	if ($sensorTypes{$sensordata{$sensor}->{2}} eq "temperature") {
		$label = '°';
		$np->add_perfdata(
			label => $sensordata{$sensor}->{5},
			value => $sensordata{$sensor}->{4},
			uom => "Celsius");
	} elsif ($sensorTypes{$sensordata{$sensor}->{2}} eq "fan") {
		$label = 'RPM';
		$np->add_perfdata(
			label => $sensordata{$sensor}->{5},
			value => $sensordata{$sensor}->{4},
			uom => "RPM");
	}

	# Are you OK ?
	if ($sensorStatus{$sensordata{$sensor}->{3}} ne "Nominal") {
		$np->add_message( CRITICAL, "$sensordata{$sensor}->{5} is $sensorStatus{$sensordata{$sensor}->{3}} $sensordata{$sensor}->{4}$label");
	# Nominal data
	} else {
		$np->add_message( OK, "$sensordata{$sensor}->{5} is $sensorStatus{$sensordata{$sensor}->{3}} $sensordata{$sensor}->{4}$label");
	}
}


# Process messages and get return code
my ($code, $message) = $np->check_messages("join" => ($np->opts->longserviceoutput ? "\n" : " - "));

# We're done, return exit code, message and perfdata
$np->nagios_exit( $code, $message );

# Fetch SNMP data
sub snmp_fetchbase($$$$) {
	my $host = shift;
	my $community = shift;
	my $version = shift;
	my $oidbase = shift;
	
	# Setup SNMP session
	my ($session, $error) = Net::SNMP->session(
		-hostname  => $host,
		-community => $community,
		-version   => $version,
		-port      => "161"
                                         );

	# Handle errors
	$np->nagios_exit(CRITICAL, "Unable to connect to snmp host, $error") if ($error);

	# Fetch oids
	my $response = $session->get_table(-baseoid => $oidbase);

	my $err = $session->error;
	$np->nagios_exit(CRITICAL, "Unable to retrieve snmp data, $err") if ($err);

	# Return SNMP Table hash
	return $response;
}

