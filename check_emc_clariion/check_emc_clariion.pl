#!/usr/bin/perl -w

# nagios: -epn
# ------------------------------------------------------------------------------
# check_emc_clariion.pl - checks the EMC CLARIION SAN devices
# Copyright (C) 2005  NETWAYS GmbH, www.netways.de
# Author: Michael Streb <michael.streb@netways.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# $Id$
# ------------------------------------------------------------------------------
# 

# basic requirements
use strict;
use Getopt::Long;
use File::Basename;
use Pod::Usage;

# predeclared subs
use subs qw/print_help check_sp check_disk check_portstate check_hbastate check_cache check_faults/;
my $opt_sp="";
my $missing_bus="";
my $missing_enclosure="";
# predeclared vars
use vars qw (
  $PROGNAME
  $VERSION
  $NAVICLI
  $NAVISECCLI

  %state_names
  $state

  $opt_host
  $opt_sp
  $opt_verbose
  $opt_help
  $opt_checktype
  $opt_pathcount
  $opt_node
  $opt_user
  $opt_password

  $output

  $secure

);

my $output;

### add some declaration in order to manage the --port option for check_portstate();
my $opt_port;
$opt_port=-1;

# a variable in order to manage the secure mode of Navicli
my $secure;
$secure=0;

# timeout in seconds for calls to navi(sec)cli
my $clitimeout;
$clitimeout=18;

$SIG{ALRM} = sub {
   print "CLI call timeout";
   exit 3;
};

# Main values
$PROGNAME = basename($0);
$VERSION  = '1.0';
$NAVICLI = '/opt/Navisphere/bin/navicli';
$NAVISECCLI = '/opt/Navisphere/bin/naviseccli';

# Nagios exit states
our %states = (
	OK       => 0,
	WARNING  => 1,
	CRITICAL => 2,
	UNKNOWN  => 3
);

# Nagios state names
%state_names = (
	0 => 'OK',
	1 => 'WARNING',
	2 => 'CRITICAL',
	3 => 'UNKNOWN'
);

# Get the options from cl
Getopt::Long::Configure('bundling');
GetOptions(
	'h'       => \$opt_help,
	'help'    => \$opt_help,
	'H=s'     => \$opt_host,
	'node=s'  => \$opt_node,
	'sp=s'    => \$opt_sp,
	't=s'     => \$opt_checktype,
	'u=s'     => \$opt_user,
	'p=s'     => \$opt_password,
	'port=s'  => \$opt_port,
	'paths=s' => \$opt_pathcount
  ) || print_help(2);

# If somebody wants to the help ...
if ($opt_help) {
	print_help(2);
}
# check if user and password for Naviseccli is given
# If it is providen, then it passes in secure mode for the command to the array.
# else we are staying in navicli mode
if ( $opt_user && $opt_password ) {
	$secure = 1;
}

# Check if all needed options present.
if ( $opt_host && $opt_checktype ) {
	# do the work
	alarm($clitimeout);
	if ($opt_checktype eq "sp" && $opt_sp ne "") {
		check_sp();
	}
	if ($opt_checktype eq "disk") {
		check_disk();
	}
	if ($opt_checktype eq "cache") {
		check_cache();
	}
	if ($opt_checktype eq "faults") {
		check_faults();
	}
	if ($opt_checktype eq "portstate" && $opt_sp ne "") {
		check_portstate();
	}
	if ($opt_checktype eq "hbastate" && $opt_pathcount ne "" && $opt_node ne "") {
		check_hbastate();
	}
	alarm(0);
	print_help(1, 'Wrong parameters specified!');
}
else {
	print_help(2);
}

# -------------------------
# THE SUBS:
# -------------------------

# check_sp();
# check state of the storage processors
sub check_sp {
	if ($secure eq 0 ) {
		open (NAVICLIOUT ,"$NAVICLI -h $opt_host getcrus |");
	}
	if ($secure eq 1 ) {
		open (NAVICLIOUT ,"$NAVISECCLI -User $opt_user -Password $opt_password -Scope 0 -h $opt_host getcrus |");
	}
	my $sp_line = 0;
	my $error_count = 0;
	while (<NAVICLIOUT>) {
		if ($_ =~ m/^DPE|^SPE|^DAE/ ) {
			# got an DPE line
			$sp_line=1;
		}
		if ($sp_line == 1) {
			# check for SP lines
			if( $_ =~ m/^SP\s$opt_sp\s\w+:\s+(\w+)/) {
				if ($1 =~ m/(Present|Valid)/) {
					$output .= "SP $opt_sp $1,";
				} else {
					$output .= "SP $opt_sp failed,";
					$error_count++;
				}	
			}
			# check for a missing enclosure
			#if( $_ =~ m/.*Bus\s\(\d\)\sEnclosure\s\(\d\d\)\s:\sMissi.*/ ){
			#(Bus 2 Enclosure 3 : Missing)	
			if( $_ =~ m/Bus\s(\d+)\sEnclosure\s(\d+)\s:\sMissing/ ){
				my $missing_bus = $1;
				my $missing_enclosure = $2;
				#print "Missing enclosure at $missing_bus $missing_enclosure!\n";
			}
			# check for Enclosure lines
			if( $_ =~ m/Enclosure\s(\d+|\w+)\s(\w+)\s$opt_sp\d?\s(\w+):\s+(.*)/) {
				my $check = $2;
				if ($3 =~ m/Revision/ or $4 =~ m/Removed/) { }
				elsif ($4 =~ m/Present|Valid|N\/A|255.255/) {
					$output .= "$check ok,";
				} else {
					print "check: $check $3 $4 \n";
					$output .= "$check failed,";
					$error_count++;
				}	
			}
			# check for Cabling lines
				
			if( $_ =~ m/Enclosure\s(\d+|\w+)\s\w+\s$opt_sp\s(\w+)\s(\w+):\s+(.*)/) {
				my $check = $2;
				if ($4 =~ m/Removed|Present|Valid|N\/A|255.255/) {
					$output .= "$check ok,";
				} else {
					$output .= "$check failed,";
					$error_count++;
				}	
			}
			# end of section
			if ( $_ =~ m/^\s*$/) {
				$sp_line=0;
			}
		}
	}
	close (NAVICLIOUT);
	if ($error_count == 0 && $output ne "") {
		$state = 'OK';
	} elsif ($output eq "") {
		$output = "UNKNOWN: No output from $NAVICLI";
		$state = 'UNKNOWN';
	} else {
		$state = 'CRITICAL';
	}
	print $output."\n";
	exit $states{$state};
	
}

# check_disk();
# check state of the disks
sub check_disk {
	my $disk_line = 0;
	my $crit_count = 0;
	my $warn_count = 0;
	my $hotspare_count = 0;
	my $disk_ok_count = 0;
	my ($bus,$enclosure,$disk) = 0;
	$state = 'UNKNOWN';
	if ($secure eq 0 ) {
		open (NAVICLIOUT ,"$NAVICLI -h $opt_host getdisk -state |");
	}
	if ($secure eq 1 ) {
		open (NAVICLIOUT ,"$NAVISECCLI -User $opt_user -Password $opt_password -Scope 0 -h $opt_host getdisk -state |");
	}
	while (<NAVICLIOUT>) {
		# check for disk lines
		if( $_ =~ m/^Bus\s(\d+)\s\w+\s(\d+)\s+\w+\s+(\d+)/) {
			$bus = $1;
			$enclosure = $2;
			$disk = $3;
			$disk_line=1;
		}

		if ($disk_line == 1) {
			# check for States lines
			if( $_ =~ m/^State:\s+(.*)$/) {
				my $status = $1;
				if ($status =~ m/Hot Spare Ready/) {
					$hotspare_count++;
					$disk_ok_count++;
				} elsif ($status =~ m/Binding|Empty|Enabled|Expanding|Unbound|Powering Up|Ready|Transitioning/) {
					$disk_ok_count++;
				} elsif ($status =~ m/Equalizing|Rebuilding/) {
					$warn_count++;
					$output .= "Bus $bus, Enclosure $enclosure, Disk $disk is replaced or is being rebuilt, ";
				} else {
					$crit_count++;
					$output .= "Bus $bus, Enclosure $enclosure, Disk $disk is critical, ";
				}	
			}
		}

		# end of section
		if ( $_ =~ m/^\s*$/) {
			$disk_line=0;
		}
	}
	close (NAVICLIOUT);
	if ($disk_ok_count eq 0) {
		print "No disk were found !\n";
		$state = 'UNKNOWN';
	} elsif ($crit_count > 0) {
		$state='CRITICAL';
	} elsif ($warn_count > 0 || $hotspare_count eq 0) {
		$state='WARNING';
	} else {
		$state='OK';
	}
	$output .= $disk_ok_count." physical disks are OK. ".$hotspare_count." Hotspares are ready.";
	print $output."\n";
	exit $states{$state};
}

# check_cache();
# check state of the read and write cache
sub check_cache {
	my $read_state = 0;
	my $write_state = 0;
	my $write_mirrored_state = 0;
	my $crit_count = 0;
	my $warn_count = 0;
	$state = 'UNKNOWN';
	if ($secure eq 0 ) {
		open (NAVICLIOUT ,"$NAVICLI -h $opt_host getcache |");
	}
	if ($secure eq 1 ) {
		open (NAVICLIOUT ,"$NAVISECCLI -User $opt_user -Password $opt_password -Scope 0 -h $opt_host getcache |");
	}
	while (<NAVICLIOUT>) {
		# check for cache
		if( $_ =~ m/^SP Read Cache State\s+(\w+)/) {
			$read_state = $1;
			if ($read_state =~ m/Enabled/) {
				$output .= "Read cache is enable, ";
			} else {
				$output .= "Read cache is not enable ! ";
				$warn_count++;
			}
		} elsif ( $_ =~ m/^SP Write Cache State\s+(\w+)/) {
			$write_state = $1;
			if ($write_state =~ m/Enabled/) {
				$output .= "Write cache is enable, ";
			} else {
				$output .= "Write cache is not enable ! ";
				$crit_count++;
			}
		} elsif ( $_ =~ m/^Write Cache Mirrored\:\s+(\w+)/) {
			$write_mirrored_state = $1;
			if ($write_mirrored_state =~ m/YES/) {
				$output .= "Write cache mirroring is enable.";
			} else {
				$output .= "The Write cache mirroring is not enable !";
				$crit_count++;
			}
		}
	}
	close (NAVICLIOUT);
	if ( !defined($output) ) {
		print "No output from the command getcache !\n";
		$state = 'UNKNOWN';
		exit $states{$state};
	} elsif ($crit_count > 0) {
		$state='CRITICAL';
	} elsif ($warn_count > 0 ) {
		$state='WARNING';
	} else {
		$state='OK';
	}
	print $output."\n";
	exit $states{$state};
}

# check_faults();
# check state of the different faults
# only works with naviseccli
sub check_faults {
	$state = 'UNKNOWN';
	if ($secure eq 0 ) {
		print "The check of the faults only works with Naviseccli. Please provide user and password with -u and -p options !\n";
		exit $states{$state};
	}
	if ($secure eq 1 ) {
		open (NAVICLIOUT ,"$NAVISECCLI -User $opt_user -Password $opt_password -Scope 0 -h $opt_host Faults -list |");
	}
	while (<NAVICLIOUT>) {
		# check for faults on the array
		if( $_ =~ m/^The array is operating normally/) {
			$state='OK';
			$output .= $_ ;
			close (NAVICLIOUT);
			print $output."\n";			
			exit $states{$state};
		} else {
			$state='CRITICAL';
			$output .= $_ ;
		}
	}
	close (NAVICLIOUT);
	if ( !defined($output) ) {
		print "No output from the command Faults -list !\n";
		$state = 'UNKNOWN';
		exit $states{$state};
	}
	print $output."\n";
	exit $states{$state};
}

# check_portstate();
# check port state of the sp`s
sub check_portstate {
	my $sp_section = 0;
	my $sp_line = 0;
	my $portstate_line = 0;
	my $error_count = -1;
	my ($port_id,$enclosure,$disk) = 0;
	$state = 'UNKNOWN';
	if ($secure eq 0 ) {
		open (NAVICLIOUT ,"$NAVICLI -h $opt_host getall -hba |");
	}
	if ($secure eq 1 ) {
		open (NAVICLIOUT ,"$NAVISECCLI -User $opt_user -Password $opt_password -Scope 0 -h $opt_host getall -hba |");
	}
	while (<NAVICLIOUT>) {
		# check for port lines
		if ($_ =~ m/SPPORT/ ) {
			$sp_section = 1;
		}
		# check for requested SP
		if( $_ =~ m/^SP\sName:\s+SP\s$opt_sp/ ) {
			$sp_line = 1;
		}
		# check for requested port id
		if ($opt_port >=0) {
			if( $_ =~ m/^SP\sPort\sID:\s+($opt_port)$/) {
				$port_id = $1;
				$portstate_line = 1;
				$error_count = 0;
			} 
		} else {

			### if( $_ =~ m/^SP\sPort\sID:\s+($opt_port)$/) {
			if( $_ =~ m/^SP\sPort\sID:\s+(\d+)$/) {
				$port_id = $1;
				$portstate_line = 1;
				$error_count = 0;
			} 
		}

		if ($sp_section == 1 && $sp_line == 1 && $portstate_line == 1) {
			# check for Link line
			if( $_ =~ m/^Link\sStatus:\s+(.*)$/) {
				my $status = $1; 
				if ($status =~ m/Up/) {
					$output .= "SP $opt_sp Port: $port_id, Link: $status, ";
				} else {
					$output .= "SP $opt_sp Port: $port_id, Link: $status, ";
					$error_count++;
				}	
			}
			# check for Link line
			### check for Port line
			if( $_ =~ m/^Port\sStatus:\s+(.*)$/) {
				my $status = $1;
				if ($status =~ m/Online/) {
					$output .= "State: $status, ";
				} else {
					$output .= "State: $status, ";
					$error_count++;
				}	
			}
			# check for Connection Type
			if( $_ =~ m/^Connection\sType:\s+(.*)$/) {
				my $type = $1;
				$output .= "Connection Type: $type. ";
			}
			# end of section
			if ( $_ =~ m/^\s*$/) {
				$portstate_line = 0;
				### $sp_section = 0;
				if ($opt_port >=0 ) {
					$sp_section = 0;
				}
				$sp_line = 0;
			}
		}
	}
	close (NAVICLIOUT);
	if ($error_count == 0) {
		$state='OK';
	} elsif ($error_count == -1) {
		$state='UNKNOWN';
		$output = 'UNKNOWN: specified port not found '.$opt_port;
	} else {
		$state='CRITICAL';
	}
		
	print $output."\n";
	exit $states{$state};
}

# check_hbastate();
# check hba and path states for specific client
sub check_hbastate {
	$state = 'UNKNOWN';
	my $hba_node;
	my $hba_node_line = 0;
	my $hba_section = 0;
	my $hba_port_section = 0;
	my $hba_port_count = 0;
	my $hba_uid = "";
	my $error_count = 0;
	my $output = "";
	if ($secure eq 0 ) {
		open (NAVICLIOUT ,"$NAVICLI -h $opt_host getall -hba |");
	}
	if ($secure eq 1 ) {
		open (NAVICLIOUT ,"$NAVISECCLI -User $opt_user -Password $opt_password -Scope 0 -h $opt_host getall -hba |");
	}
	while (<NAVICLIOUT>) {
		if ($_ =~ m/Information\sabout\seach\sHBA/) {
			$hba_section = 1;
			$hba_port_section = 0;
			$hba_node_line = 0;
		}
		if ($hba_section == 1) {
			if ($_ =~ m/^HBA\sUID:\s+((\w+:?)+)/i) {
				$hba_uid=$1;
			}
			if ($_ =~ m/^Server\sName:\s+($opt_node)/i) {
				$hba_node = $1;
				$hba_node_line = 1;
			}
			if ($_ =~ m/Information\sabout\seach\sport\sof\sthis\sHBA/) {
				$hba_section = 0;
				$hba_port_section = 1;
			}
		}
		

		if ($hba_port_section && $hba_node_line) {
			if ($_ =~ m/SP\sName:\s+(\w+\s+\w+)/) {
				$output .= "$hba_uid connected to: $1, ";
			}
			if ($_ =~ m/SP\sPort\sID:\s+(\d+)/) {
				$output .= "port: $1, ";
			}
			if ($_ =~ m/Logged\sIn:\s+(YES)/) {
				$output .= "Logged in: $1; ";
				$hba_port_count++;
			} elsif ($_ =~ m/Logged\sIn:\s+(\w+)/) {
				$output .= "Logged in: $1; <br>";
				$error_count++;
			}
		}
	}
	close (NAVICLIOUT);
	

	if ($error_count == 0 && $hba_port_count == $opt_pathcount) {
		$state='OK';
	} elsif (lc($opt_node) ne lc($hba_node) ) {
		$state='UNKNOWN';
		$output = 'UNKNOWN: specified node not found '.$opt_node;
	} elsif ($hba_port_count != $opt_pathcount) {
		$output .= " error in pathcount from client to SAN: suggested $opt_pathcount detected $hba_port_count";
		$state='CRITICAL';
	} elsif ($error_count != 0 && $hba_port_count == $opt_pathcount) {
		$output .= " Error in Configuration, one path not connected !";
		$state='CRITICAL';
	}
		
	print $opt_node."<br>".$output."\n";
	exit $states{$state};
}

# print_help($level, $msg);
# prints some message and the POD DOC
sub print_help {
	my ( $level, $msg ) = @_;
	$level = 0 unless ($level);
	pod2usage(
		{
			-message => $msg,
			-verbose => $level,
			-noperldoc => 1
		}
	);

	exit( $states{UNKNOWN} );
}

1;

__END__

=head1 NAME

check_emc_clariion.pl - Checks EMC SAN devices for NAGIOS.


=head1 SYNOPSIS

check_emc_clariion.pl -h | --help

check_emc_clariion.pl -H <host> -t <checktype>

check_emc_clariion.pl -H <host> -u <user> -p <password> -t <checktype>


=head1 DESCRIPTION

B<check_emc_clariion.pl> receives the data from the emc devices via Navicli or Naviseccli if user and password are provided.


=head1 OPTIONS

=over 8

=item B<-h>

Display this helpmessage.

=item B<-H>

The hostname or ipaddress of the emc storage processor device.

=item B<-u>

The user used to connect to the emc storage processor device with Naviseccli.
You must use this option with -password !

=item B<-p>

The password of the user used to connect to the emc storage processor device with Naviseccli.

=item B<-t>

The check type to execute:

=back

=head2 TYPES 

the following checks are currently available

sp   - check the status of the storage processors

disk - check the status of the physical disks attached in the DAE`s

cache - check the status of the read and write cache

faults - Report the different faults on the array

portstate - check the status of the FC ports in the SP`s

hbastate - check the connection state of the specified node

=head3 TYPE OPTIONS

=head4 sp

=over 8

=item B<--sp>

The storageprocessor to check e.g. A or B 

=back

=head4 portstate

=over 8

=item B<--sp>

The storageprocessor to check e.g. A or B 

=item B<--port>
 
The port ID to check e.g. 0 or 1 or 0, 1, 2 or 3 for Clariion CX3-80

- if not specified, all ports are checked

=back

=head4 hbastate

=over 8

=item B<--node>

The node name to check out of navisphere 

=item B<--paths>

The number of available FC Paths from the client to the SAN Infrastructure e.g. 2

=cut

=back

=head1 VERSION

$Id$

=head1 AUTHOR

NETWAYS GmbH, 2008, http://www.netways.de.

Written by Michael Streb <michael.streb@netways.de>.

Please report bugs through the contact of Nagios Exchange, http://www.nagiosexchange.org. 
