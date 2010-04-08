#!/usr/bin/perl -w
#
# Copyright 2010, Tomas Edwardsson 
#
# check_windows_dfs.pl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# windows_dfs.pl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Nagios::Plugin;
use strict;


# PATH to check_nrpe
my $nrpepath = '/nagios/libexec/check_nrpe';


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
	spec => 'longserviceoutput|l',
	help => '-l, --longserviceoutput',
	default => undef,
	required => 0,
);

# Parse Arguments
$np->getopts();



open NRPE, $nrpepath . " -H " . $np->opts->hostname . " -c get_dfsdiag_testdcs|" or
	nagios_exit(UNKNOWN, "Unable to execute NRPE: $!");



# Result
my @results = ();

# First line, for NRPE run problems
my $first_line = '';

# Loop through each installed sensor
while (my $line = <NRPE>) {
	print "NRPE Output: $line" if ($np->opts->verbose);
#NRPE Output: DFSDIAG_INFO - APPL - DFS Service on SMSADL5 is OK.

	$line =~ s/[\n\r]//g;
	$line =~ s/[\.,]$//g;
	$first_line = $line if (!$first_line);
	if ($line =~ /^\s*DFSDIAG_(\S+) - (.*) - (.*)$/) {
		next if ($1 eq 'ERROR' and $3 eq 'Access is denied');
		push @results, { "state" => $1, "source" => $2, "message" => $3 };
	}
}

close NRPE;
my $err = $!;
my $exit_code = $? >> 8;

if ($exit_code) {
	$np->nagios_exit(UNKNOWN, "Unable to run nrpe: $first_line");
}

# ANY Problems ?
my $ok = 1;
foreach my $m (@results) {
	$ok = 0 if ($m->{state} ne "INFO");
}

if ($ok) {
	$np->add_message("OK", "DFS tests successfull");
} elsif ($np->opts->longserviceoutput) {
	$np->add_message("OK", "DFS some tests unsuccessfull");
}

# Hack for multiline status output
#$np->add_message( "OK", "" ) if ($np->opts->longserviceoutput);

foreach my $m (@results) {
	if ($m->{state} eq 'INFO') {
		if ($np->opts->longserviceoutput) {
			$np->add_message( "OK", "$m->{state} - $m->{source} - $m->{message}" );
		}
	} elsif ($m->{state} eq 'WARNING') {
		$np->add_message( "WARNING", "$m->{state} - $m->{source} - $m->{message}" );
	} elsif ($m->{state} eq 'ERROR') {
		$np->add_message( "CRITICAL", "$m->{state} - $m->{source} - $m->{message}" );
	} else {
		$np->add_message( "UNKNOWN", "state " . $m->{state} . " is unkown ? " . $m->{message} );
	}
}



# Process messages and get return code
my ($code, $message) = $np->check_messages("join" => ($np->opts->longserviceoutput ? "\n" : " - "), "join_all" => $np->opts->longserviceoutput);

# We're done, return exit code, message and perfdata
$np->nagios_exit( $code, $message );


