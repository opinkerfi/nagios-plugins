#!/usr/bin/perl -w

use strict;
use Nagios::Plugin;
use Data::Dumper;


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
        spec => 'username|u=s',
        help => '-u, --username=<username>',
        required => 1,
);

$np->add_arg(
        spec => 'password|p=s',
        help => '-p, --password=<password>',
        required => 1,
);

$np->add_arg(
        spec => 'share|s=s',
        help => '-s, --share=<password>',
        required => 1,
);

$np->add_arg(
        spec => 'kerberos|k',
        help => '-k, --kerberos',
        required => 0,
);

$np->add_arg(
        spec => 'writefile|w=s',
        help => '-w, --writefile=<filepath>',
        required => 0,
);



sub testbin($) {
	my $program = shift;
	eval {
		system("$program &> /dev/null");
	};
	my $exit_value  = $? >> 8;
	if ($exit_value != 127) {
		return 0;
	} else {
		print "Could not execute $program\n";
		exit 2;
	}
}

sub usage() {
	print <<EOUSAGE;
Usage $0 -H <hostname> -s <share> -u <username> -p <password>
EOUSAGE
}




testbin("smbclient");
testbin("kinit");
testbin("kdestroy");


$np->getopts;

# Login with kerberos
if ($np->opts->kerberos) {
	my $tmp = `mktemp check-cifs-XXXXXX --tmpdir=/tmp`;
	my $rc = $? >> 8;
	chomp($tmp);

	if ($rc) {
		nagios_exit(UNKNOWN, "Unable to run mktemp for kerberos cache");
	}
	my $kcmd = sprintf("echo '%s' | kinit -c %s '%s' 2>&1", $np->opts->password, $tmp, $np->opts->username);
	my $kinit = `$kcmd`;
	my $exit_value  = $? >> 8;

	if ($exit_value != 0) {
		chomp $kinit;
		nagios_exit(CRITICAL, "Critical: Unable to log in with kerberos - $kinit\n";
	}
}

my @smbclient_opts;
my @smbclient_commands;


if ($np->opts->kerberos) {
	push @smbclient_opts, '-k'
} else {
	push @smbclient_opts, sprintf("'%s'", $np->opts->username), '-U', "'$np->opts->username'", 
}

print "smbclient " . join(" ", @smbclient_opts) . "\n";


__END__
	my $kdestroy = `echo $parms{pass} | kdestroy -c $tmp`;
	$exit_value  = $? >> 8;
	#print "kdestroy: $kdestroy\nrc: $exit_value\n";

