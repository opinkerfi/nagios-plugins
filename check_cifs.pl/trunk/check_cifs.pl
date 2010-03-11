#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use File::MkTemp qw(mktemp);
use Data::Dumper;

Getopt::Long::Configure ("posix_default", "no_ignore_case");
my %parms;


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

sub help() {
	print <<EOUSAGE;
Usage $0 -H <hostname> -s <share> -u <username> -p <password>

	--host,		-H		Hostname
	--share,	-s		Share
	--user,		-u		Username
	--pass,		-p		Password
	--kerberos,	-k		Enable Kerberos login
	--writefile,	-w		Tries to write to a file on the share
	--readfile,	-r		Tries to read the specified file
EOUSAGE
	#exit 0;
}

my $result = GetOptions (
	"help|h" => \$parms{help},
	"user|u=s" => \$parms{user},
	"pass|p=s" => \$parms{pass},
	"kerberos|k" => \$parms{kerberos},
	"debug|d" => \$parms{debug},
	"verbose|v"  => \$parms{verbose},
	"writefile=s"  => \$parms{writefile},
	"hostname|H=s"  => \$parms{hostname},
	"share|s=s"  => \$parms{share});


print Dumper(\%parms) . "\n" if ($parms{debug});

if ($parms{help}) {
	help();
}

if (!$parms{user} or !$parms{pass} or !$parms{hostname} or !$parms{share}) {
	usage();
	exit 2;
}


my $tmp = mktemp("check-cifs-XXXXXX", "/tmp");
testbin("smbclient");
testbin("kinit");
testbin("kdestroy");


# Login with kerberos
if ($parms{kerberos}) {
	my $kinit = `echo $parms{pass} | kinit -c $tmp $parms{user} 2>&1`;
	my $exit_value  = $? >> 8;

	if ($exit_value != 0) {
		chomp $kinit;
		print "Critical: Unable to log in with kerberos - $kinit\n";
		exit 2;
	}
}

my @smbclient_opts;
my @smbclient_commands;

if ($parms{kerberos}) {
	push @smbclient_opts, '-k'
} else {
	push @smbclient_opts, "'$parms{pass}'", '-U', "'$parms{user}'", 
}



__END__
	my $kdestroy = `echo $parms{pass} | kdestroy -c $tmp`;
	$exit_value  = $? >> 8;
	#print "kdestroy: $kdestroy\nrc: $exit_value\n";

