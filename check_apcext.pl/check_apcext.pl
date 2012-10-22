#!/usr/bin/perl
#
# check_apcext.pl - APC Extra gear monitoring plugin for Nagios
# 05.02.07 Paul Venezia
#
# v0.0.1
#
#

use Net::SNMP;
use Getopt::Std;
use Data::Dumper;
use vars qw/ %opt /;
use strict;

sub getmasked_values ($$);
sub f2c ($);

if ($ARGV[0] =~ /(--help|-h|help)/ || !defined$ARGV[0]) {
	&usage;
	exit 0;
}

my $opts = 's:lmC:H:p:w:c:';
getopts ( "$opts", \%opt ) or &usage;


my $host = $opt{H};
my $comm = $opt{C};
my $param = $opt{p};
my $warn = $opt{w};
my $crit = $opt{c};
my $metric = $opt{m};
my $list = $opt{l};
my $sensor_int_name = $opt{s};

my ($oid, $oidbase, $fval, $unit, $outmsg);
my $retval = 0;
my %rpduamps;

my %oids = ( 
	'nbmstemp' => {
		'label' => 'Temp',
		'unit'	=> 'degF',
		'oidbase' => '.1.3.6.1.4.1.5528.100.4.1.1.1',
		'sensor_key' => 5,
		'sensor_val' => 2,
		'$val * 0.1'
		},
	'nbmshum' => {
		'label' => 'Humidity',
		'unit'	=> '%',
		'oidbase' 	=> '.1.3.6.1.4.1.5528.100.4.1.2.1',
		'sensor_key' => 5,
		'sensor_val' => 8,
		},
	'nbmsairflow' => {
		'label' => 'Air Flow',
		'unit'	=> 'CFM',
		'oidbase' 	=> '.1.3.6.1.4.1.5528.100.4.1.5.1',
		'sensor_val' => 8,
		'sensor_key' => 5,
		'mod'	=> 'lt'
		},
	'nbmsaudio' => {
		'label' => 'Audio Level',
		'unit'	=> '',
		'oidbase' 	=> '.1.3.6.1.4.1.5528.100.4.1.4.1',
		'sensor_val' => 7,
		'sensor_key' => 5,
		'mod'	=> ''
		},
	'rpduamps' => {
		'label' => 'Power Output',
		'unit'	=> 'Amps',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.12.2.3.1.1.2.',
		'cdef'  => '$val * .10'
		},
	'acscstatus' => {
		'label' => 'Status',
		'unit'	=> '',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.4.1.2.1.0'
		},
	'acscload' => {
		'label' => 'Cooling Load',
		'unit'	=> 'kW',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.4.1.2.3.0',
		'cdef'  => '$val * .10'
		},
	'acscoutput' => {
		'label' => 'Cooling output',
		'unit'	=> 'kW',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.4.1.2.2.0',
		'cdef'  => '$val * .10'
		},
	'acscsupair' => {
		'label' => 'Supply Air',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.4.1.2.8.0',
		'cdef'  => '$val * .10'
		},
	'acscretair' => {
		'label' => 'Return Air',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.4.1.2.10.0',
		'cdef'  => '$val * .10'
		},
	'acscairflow' => {
		'label' => 'Airflow',
		'unit'	=> 'CFM',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.4.1.2.4.0',
		},
	'acscracktemp' => {
		'label' => 'Rack Inlet Temp',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.4.1.2.6.0',
		'cdef'  => '$val * .10'
		},
	'acsccondin' => {
		'label' => 'Cond Inlet Temp',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.4.1.2.30.0',
		'cdef'  => '$val * .10'
		},
	'acsccondout' => {
		'label' => 'Cond Outlet Temp',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.4.1.2.28.0',
		'cdef'  => '$val * .10'
		},
	'acrcstatus' => {
		'label' => 'Status',
		'unit'	=> '',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.1.0'
		},
	'acrcload' => {
		'label' => 'Cooling Load',
		'unit'	=> 'kW',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.2.0',
		'cdef'  => '$val * .10'
		},
	'acrcoutput' => {
		'label' => 'Cooling Output',
		'unit'	=> 'kW',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.3.0',
		'cdef'  => '$val * .10'
		},
	'acrcairflow' => {
		'label' => 'Airflow',
		'unit'	=> 'CFM',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.4.0'
		},
	'acrcracktemp' => {
		'label' => 'Rack Inlet Temp',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.6.0',
		'cdef'  => '$val * .10'
		},
	'acrcsupair' => {
		'label' => 'Supply Air',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.8.0',
		'cdef'  => '$val * .10'
		},
	'acrcretair' => {
		'label' => 'Return Air',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.10.0',
		'cdef'  => '$val * .10'
		},
	'acrcfanspeed' => {
		'label' => 'Fan Speed',
		'unit'	=> '%',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.16.0',
		'cdef'	=> '$val * .10',
		},
	'acrcfluidflow' => {
		'label' => 'Fluid Flow',
		'unit'	=> 'GPM',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.21.0',
		'cdef'	=> '$val * .10',
		'mod'	=> 'lt'
		},
	'acrcflenttemp' => {
		'label' => 'Entering Fluid Temp',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.23.0',
		'cdef'  => '$val * .10'
		},
	'acrcflrettemp' => {
		'label' => 'Returning Fluid Temp',
		'unit'	=> 'degF',
		'oid' 	=> '.1.3.6.1.4.1.318.1.1.13.3.2.2.2.25.0',
		'cdef'  => '$val * .10'
		},
	);

if ($list) {
        my ($baseoid, $int_name_id, $value_id) = @_;

	my ($session, $error) = Net::SNMP->session(
                                           -hostname  => $host,
                                           -community => $comm,
                                           -version   => 1,
               #                                           -translate => [-octetstring => 0x0],
                                           -port      => "161"
                                         );
	my $response = $session->get_table(-baseoid => ".1.3.6.1.4.1.5528.100.2.1.1");
        my $err = $session->error;
        if ($err){
                $retval = 3;
                $outmsg = "UNKNOWN";
                $session->close();
                print "$outmsg $err - SNMP Error connecting to $host\n";
                exit $retval;
        }
	my %sensor;
	foreach my $k (keys %{$response}) {
		my ($type, $id) = (split(/\./, $k))[-2,-1];
		next if ($type != 1 and $type != 4);
		next if ($id <  2000000000);
		if ($type == 1) {
			$sensor{$id}->{"int_name"} = $response->{$k};
		} else {
			$sensor{$id}->{"friendly_name"} = $response->{$k};
		}
	}

	print <<"	EO";
Specify a sensor by using the -s and the INTERNAL name of the sensor

Detected sensors:

	EO
	printf("\t%-32s %s\n", "Friendly Name", "Internal Name");
	foreach my $id (sort { $sensor{$a}->{"friendly_name"} cmp $sensor{$b}->{"friendly_name"} } keys %sensor) {
		printf ("\t%-32s %s\n", "\"$sensor{$id}->{friendly_name}\"", "\"$sensor{$id}->{int_name}\"");
	}
	exit 0;


} elsif (!$oids{$param}) {
	print "No test parameter specified";
	exit 3;
} else {
	$oid = $oids{$param}->{oid};
	$oidbase = $oids{$param}->{oidbase};
}

my ($session, $error) = Net::SNMP->session(
                                           -hostname  => $host,
                                           -community => $comm,
                                           -version   => 1,
               #                                           -translate => [-octetstring => 0x0],
                                           -port      => "161"
                                         );

	
if ($param eq "rpduamps") {
#	$param = "RackPDU";
	my $i;
	for ($i=1;$i<4;$i++) {
	  my $phoid = $oid . $i;
	  my $response = $session->get_request($phoid);
	my $err = $session->error;
	if ($err){
	        $retval = 3;
		$outmsg = "UNKNOWN";
		$session->close();
		print "$outmsg $err - SNMP Error connecting to $host\n";
		exit $retval;		
	}
	  $rpduamps{$i} = $response->{$phoid};
	}
		$session->close;
		#$crit = ($crit * 10);
		#$warn = ($warn * 10);

	$unit = "Amps";
	foreach my $ph ( sort keys %rpduamps ) {
		my $tphase = ($rpduamps{$ph} * .1);

		if (($tphase >= $crit) && ($retval < 2)) {
			$retval = 2;
			$outmsg = "CRITICAL";
			
		} elsif (($tphase >= $warn) && ($retval < 1)) {
			$retval = 1;
			$outmsg = "WARNING";
		
		} elsif ($retval < 1) {
			$retval = 0;
			$outmsg = "OK";
		}
		
		$fval .= "Phase $ph: " . $tphase;
		#$fval .= "Phase $ph: " . ($tphase * .1);
		if ($ph lt 3) {
			$fval .= " Amps, ";
		#} else {
		#	$fval .= " ";
		}
		
	}
	
} else {
	my $val;
	if ($oid) {
		my $response = $session->get_request($oid);

		my $err = $session->error;
		if ($err){
	        	$retval = 3;
			$outmsg = "UNKNOWN";
			$session->close();
			print "$outmsg $err - SNMP Error connecting to $host\n";
			exit $retval;		
		}
	
	
		$val = $response->{$oid};
		$session->close();
	
	
	} else {
		my $snmpd = getmasked_values($oidbase, { $oids{$param}->{sensor_key} => 'sensor_key',
						$oids{$param}->{sensor_val} => 'sensor_val' });

		if ((keys %{$snmpd}) > 1 && !$sensor_int_name) {
			print "UNKNOWN - Many sensors found but none specified, see -s and -l\n";
			exit 3;
		} elsif ((keys %{$snmpd}) == 0) {
			print "UNKNOWN - no sensors found on this device\n";
			exit 3;
		} else {
			my $id = (keys %{$snmpd})[0];
			$val = $snmpd->{$id}->{sensor_val};
		}

		if ($sensor_int_name) {
			foreach my $k (keys %{$snmpd}) {
				if (lc($snmpd->{$k}->{sensor_key}) eq lc($sensor_int_name)) {
					$val = $snmpd->{$k}->{sensor_val};
				}
			}
		}
		if ($val eq "") {
			print Dumper $snmpd;
			print "UNKNOWN Unable to get sensor status\n";
			exit 3;
		}
	}
	if ($param eq "acscstatus" || $param eq "acrcstatus") {
		if ($val == 1) {
			$fval = "Standby";
	       		$retval = 1;
			$outmsg = "WARNING";
		} elsif ($val == 2) {
			$fval = "On";
	       		$retval = 0;
			$outmsg = "OK";
		}
	} else {

		if ($oids{$param}->{cdef}) {
			$fval = eval "$oids{$param}->{cdef}";
		} else {
			$fval = $val;
		}

		if ($metric and $oids{$param}->{unit} eq 'degF') {
			$oids{$param}->{unit} = 'degC';
			$fval = sprintf("%.1f", f2c($fval));
		}

		if ($fval > $crit) {
        		$retval = 2;
			$outmsg = "CRITICAL";
		} elsif ($fval > $warn) {	
        		$retval = 1;
			$outmsg = "WARNING";
		} else {
			$retval = 0;
			$outmsg = "OK";
		}
	}
} 

print "$outmsg - " . $oids{$param}->{label} . " " .$fval . " " . $oids{$param}->{unit} . " | $param=$fval$oids{$param}->{unit}\n";


exit $retval;

sub usage {

print "Usage: $0 -H <hostip> -C <community> -p <parameter> -w <warnval> -c <critval> [-l] [-s sensor]\n";
print "\nParameters:\n";
print  <<"	EO";
APC NetBotz 
	nbmstemp	NetBotz main sensor temp	| nbmshum 	NetBotz main sensor humidity
	nbmsairflow	NetBotz main sensor airflow	| nbmsaudio	NetBotz main sensor audio
	-l 		List connected sensors		| -s sensor	Sensor we want info from

APC Metered Rack PDU
	rpduamps	Amps on each phase

APC ACSC In-Row
	acscstatus	System status (on/standby)	| acscload	Cooling load
	acscoutput	Cooling output			| acscsupair	Supply air
	acscairflow	Air flow			| acscracktemp	Rack inlet temp
	acsccondin	Condenser input temp		| acsccondout	Condenser outlet temp 

APC ACRC In-Row
	acrcstatus	System status (on/standby)	| acrcload	Cooling load
	acrcoutput	Cooling output			| acrcairflow	Air flow
	acrcracktemp	Rack inlet temp			| acrcsupair	Supply air
	acrcretair	Return air			| acrcfanspeed	Fan speed
	acrcfluidflow	Fluid flow			| acrcflenttemp	Fluid entering temp
	acrcflrettemp	Fluid return temp
	EO

	exit 3;

}

sub f2c($) {
	my $f = shift;

	return ($f - 32) * (5/9);
}

sub getmasked_values ($$) {
	my ($baseoid, $values) = @_;

	my ($session, $error) = Net::SNMP->session(
                                           -hostname  => $host,
                                           -community => $comm,
                                           -version   => 1,
                                           -port      => "161"
                                         );
	my $response = $session->get_table(-baseoid => $baseoid);
        my $err = $session->error;
        if ($err){
                $retval = 3;
                $outmsg = "UNKNOWN";
                $session->close();
                print "$err - SNMP Error connecting to $host\n";
                exit $retval;
        }

	my %snmpdata;
	foreach my $k (keys %{$response}) {
		my ($type, $id) = (split(/\./, $k))[-2,-1];
		if ($values->{$type}) {
			$snmpdata{$id}->{$values->{$type}} = $response->{$k};
		}
	}
	return \%snmpdata;
}
