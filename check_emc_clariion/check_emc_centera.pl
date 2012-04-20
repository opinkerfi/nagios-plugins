#!/usr/bin/perl -w

# ------------------------------------------------------------------------------
# check_emc_centera.pl - checks the EMC CENTERA storage devices
# Copyright (C) 2008  NETWAYS GmbH, www.netways.de
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
# $Id: check_emc.pl 1725 2007-07-31 13:11:06Z mstreb $
# ------------------------------------------------------------------------------

# basic requirements
use strict;
use Getopt::Long;
use File::Basename;
use Pod::Usage;
use POSIX;

# predeclared subs
use subs qw/print_help check_value bool_state trim/;

# predeclared vars
use vars qw (
  $PROGNAME
  $VERSION
  $JAVA
  $CENTERA_VIEWER

  %state_names
  $state

  $opt_host
  $opt_user
  $opt_pass
  $opt_node
  $opt_pool
  $node_name
  $opt_verbose
  $opt_help
  $opt_checktype
  $opt_script
  $opt_man

  $output

);

my $dummy;

# Main values
$PROGNAME = basename($0);
$VERSION  = '1.1';
$JAVA = '/usr/bin/java';
$CENTERA_VIEWER = "/usr/local/nagios/libexec/EMC/CenteraViewer\.jar";

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
	'H=s'     => \$opt_host,
	'u=s'     => \$opt_user,
	'p=s'     => \$opt_pass,
	'node=s'     => \$opt_node,
	'pool=s'     => \$opt_pool,
	't=s',    => \$opt_checktype,
	'script=s',    => \$opt_script,
	'man',    => \$opt_man
  )
  || print_help( 1, 'Please check your options!' );

# If somebody wants to the help ...
if ($opt_help) {
	print_help(1);
}
elsif ($opt_man) {
        print_help(99);
}

# Check if all needed options present.
if ( $opt_host && $opt_checktype && $opt_user && $opt_pass && $opt_script) {
	# do the work
	if ($opt_checktype eq "node_status" && $opt_node ne "") {
		check_node_status();
	}
	if ($opt_checktype eq "capacity" && $opt_pool ne "") {
		check_pool_capacity();
	}
	print_help(1, 'Wrong parameters specified!');
}
else {

	print_help( 1, 'Too few options!' );
}

# -------------------------
# THE SUBS:
# -------------------------

# check_node_status();
# checks the node status of the centera devices
sub check_node_status {
	open (VIEWEROUT ,"$JAVA -cp $CENTERA_VIEWER com.filepool.remote.cli.CLI -u $opt_user -p $opt_pass -ip $opt_host -script $opt_script |");
	my $node_line = 0;
	my $error_count = 0;
	my $access_node = 0;
	while (<VIEWEROUT>) {
		chomp $_;
		if ($_ =~ m/Node\s+($opt_node)/ ) {
			# got an DPE line
			$node_line = 1;
			$node_name = $1;
			$access_node = 0;
			next;
		} 
		if ($node_line == 1) {
			my $status;
			my $roles;
			if ($_ =~ m/^\s+Status:\s+(\w+)$/) {
				$status = $1;
				if ($status =~ m/on/) {
					$output = "$node_name: Status $status; ";
				} else {
					$output = "$node_name: Status $status; ";
					$error_count++;
				}
			}	
			if ($_ =~ m/Roles:\s+(.*)/) {
				$roles = $1;
				if ($roles =~ m/access/) {
					$output .= "Roles $roles";
					$access_node = 1;
				} else {
					$output .= "Roles $roles";
					$node_line = 0;
				}
				if ($access_node) {;
					$output .= "; ";
				}
			}	

			if ($access_node) {
				if ($_ =~ m/Hardware\sFailures\/Exceptions:\s+\w+:connected/) {
					$output .= "access node connected";
					$node_line = 0;
				} elsif ($_ =~ m/Hardware\sFailures\/Exceptions:\s+\w+/) {
					$output .= "access node NOT connected";
					$node_line = 0;
					$error_count++;
				}
			}
		}
	}
	close (VIEWEROUT);

	if ($error_count == 0 && $output ne "") {
		$state = 'OK';
	} elsif ($output eq "" ) {
		$output = "UNKNOWN: node $opt_node not found";
		$state = 'UNKNOWN';
	} else {
		$state = 'CRITICAL';
	}
	print $output."\n";
	exit $states{$state};
	
}

# check_pool_capacity();
# checks the node status of the centera devices
sub check_pool_capacity {
	open (VIEWEROUT ,"$JAVA -cp $CENTERA_VIEWER com.filepool.remote.cli.CLI -u $opt_user -p $opt_pass -ip $opt_host -script $opt_script |");
	my @values;
	while (<VIEWEROUT>) {
		chomp $_;
		if ($_ =~ m/^$opt_pool/ ) {
			@values = split(/\s+/, $_);
		}
	}
	close (VIEWEROUT);

	# strip out the seperator
	$values[1] =~ s/,//g;
	$values[3] =~ s/,//g;
	$values[5] =~ s/,//g;
	
	$output = "Pool $opt_pool: Size: $values[1] $values[2], Used: $values[3] $values[4] , Free: $values[5] $values[6]";	
	print $output."\n";
	exit $states{'OK'};
	
}

# print_help($level, $msg);
# prints some message and the POD DOC
sub print_help {
	my ( $level, $msg ) = @_;
	$level = 0 unless ($level);
	pod2usage(
		{
			-message => $msg,
			-verbose => $level
		}
	);

	exit( $states{UNKNOWN} );
}

1;

__END__

=head1 NAME

check_emc.pl - Checks EMC SAN devies for NAGIOS.

=head1 SYNOPSIS

check_emc.pl -h

check_emc.pl --man

check_emc.pl -H <host> -t <checktype>

=head1 DESCRIPTION

B<check_emc.pl> recieves the data from the emc devices via navicli.

=head1 OPTIONS

=over 8

=item B<-h>

Display this helpmessage.

=item B<-H>

The hostname or ipaddress of the emc centera device.

=item B<-t>

The check type to execute:

the following checks are currently available

node_status   - checks the status of the centera nodes

capacity      - check the drive usage

=item B<-u>

administrative user used for the cli connection

=item B<-p>

administrative password used for the cli connection

=item B<--node>

the cluster node to check (ony used with check type node_status)

=item B<--script>

cli script with commands executed on the centera command line

=cut

=head1 VERSION

$Id: check_emc.pl 1725 2008-04-16 13:11:06Z mstreb $

=head1 AUTHOR

NETWAYS GmbH, 2008, http://www.netways.de.

Written by Michael Streb <michael.streb@netways.de>.

Please report bugs through the contact of Nagios Exchange, http://www.nagiosexchange.org. 
