#! /usr/bin/perl -w
################################################################################
# check_snmp_patchlevel.pl v1.2
#
# Nagios plugin to check the OS version string through SNMP sysDescr value.
# Please adjust the line setting the "use lib" path so utils.pm can be found.
# @2009 public[at]frank4dd[dot]com
#
# updates:
# 20090228 v1.1 adds support for Cisco PIX
# 20091117 v1.2 adds support for selection of SNMP version 1 or 2
################################################################################

use strict;
use Getopt::Long;
use Net::SNMP;

use vars qw($opt_V $opt_v $opt_h $opt_H $opt_g $opt_C $opt_f $PROGNAME @raw_data $output);
use lib "/usr/lib/nagios/plugins"  ;
use utils qw(%ERRORS &print_revision &support &usage);

$PROGNAME = "check_snmp_patchlevel.pl";

sub print_help ();
sub print_usage ();

$ENV{'PATH'}='';
$ENV{'BASH_ENV'}=''; 
$ENV{'ENV'}='';

#print("Args: $#ARGV\n");
if ($#ARGV == -1) { usage("Missing arguments\.\nUsage: $PROGNAME -H <host> [-v snmp version 1|2] -g <ios|asa|pix> [-C community] [-f <config file>]\n"); }

Getopt::Long::Configure('bundling');
GetOptions
        ("V"   => \$opt_V, "plugin-version"=> \$opt_V,
         "v=s" => \$opt_v, "snmp-version=s"=> \$opt_v,
         "h"   => \$opt_h, "help"          => \$opt_h,
         "H=s" => \$opt_H, "hostname=s"    => \$opt_H,
         "C=s" => \$opt_C, "community=s"   => \$opt_C,
         "f=s" => \$opt_f, "configfile=s"  => \$opt_f,
         "g=s" => \$opt_g, "devicegroup=s" => \$opt_g);

if ($opt_V) {
	print_revision($PROGNAME,'$Revision: 120 $');
	exit $ERRORS{'OK'};
}

if ($opt_h) { print_help(); }

# The SNMP port defaults to 161. It is not made a commandline option yet.
my $opt_p = 161;
# The SNMP timeout is set to 5 seconds. It is not made a commandline option yet.
my $opt_t = 5;

################################################################################
# Check for the "required" options -H <host name or IP>, -g <ios|asa|pix>
################################################################################

($opt_H) || usage("Host name/address not specified\. Use $PROGNAME -h for help\.\n");
my $host = $1 if ($opt_H =~ /([-.A-Za-z0-9]+)/);
($host) || usage("Invalid host: $opt_H\n");

($opt_g) || usage("Device type not specified\. Use $PROGNAME -h for help\.\n");
# no sanity chck here, it is done below where $opt_g is parsed.

################################################################################
# Check for the "optional" options -v -C, -f, -s
################################################################################
# set the SNMP version or assume it is "1" (default)
($opt_v) || ($opt_v = 1) ;
if ( $opt_v ne 1 && $opt_v ne 2) {
  printf("UNKNOWN: SNMP version $opt_v.\n");
  exit $ERRORS{'UNKNOWN'};
}

# set the SNMP community or assume it is "public" (default)
($opt_C) || ($opt_C = "public") ;

# load config file
if($opt_f) { &read_config(); }

################################################################################
# We fetch the system description via SNMP. It should contain the OS version.
# The SNMP OID we query is .1.3.6.1.2.1.1.1.0 = SNMPv2-MIB::sysDescr.0
# $version = `/usr/bin/snmpget -OQv -v 1 -c $opt_C $host .1.3.6.1.2.1.1.1.0`;
################################################################################
my $snmpdata="";
my $response="";
my $sysdesc_oid = ".1.3.6.1.2.1.1.1.0";

my ($session, $error) = Net::SNMP->session(
  -hostname  => $opt_H,
  -community => $opt_C,
  -port      => $opt_p,
  -timeout   => $opt_t,
  -version   => $opt_v
);

if(!defined($session)) { printf("UNKNOWN: %s.\n", $error); exit $ERRORS{'UNKNOWN'}; }

$response = $session->get_request( -varbindlist => [$sysdesc_oid]);

if(!defined($response)) { 
  printf("UNKNOWN: %s.\n", $session->error); 
  $session->close;
  exit $ERRORS{'UNKNOWN'};
}

$snmpdata = $response->{$sysdesc_oid};
$session->close;

################################################################################
# There is no standardized way for displaying OS version and patch levels.
# Depending on the vendor and OS, we need to parse this data differently.
# We don't have a switch statement yet (coming in perl 5.10), so we need
# to cascade the if-thens
################################################################################

################################################################################
# Example response for Cisco Routers, here a from a Cat-6506:
# Version: Cisco Internetwork Operating System Software
# IOS (tm) MSFC2 Software (C6MSFC2-JSV-M), Version 12.1(27b)E3, RELEASE SOFTWARE (fc1)
#                                                  ^^^^^^^^^^^
# Technical Support: http://www.cisco.com/techsupport
# Copyright (c) 1986-2007 by cisco Systems, Inc.
# Compiled Tue 07-Aug-0
# Example response for Cisco Routers, here a from a Cat-3750:
# Cisco IOS Software, C3750 Software (C3750-IPBASE-M), Version 12.2(25)SEE2, RELEASE SOFTWARE (fc1)
#                                                              ^^^^^^^^^^^^
# Copyright (c) 1986-2006 by Cisco Systems, Inc.
# Compiled Fri 28-Jul-06 08:46 by yenanh
################################################################################
my $version="";

if ($opt_g =~ /ios/) { 
  my $line="";
  my @lines = split ('\n', $snmpdata);
  foreach $line (@lines) {
    if($line =~ /IOS .*/) { 
      (my @fields) = split(', ', $line);
      foreach my $field (@fields) {
        if($field =~ /Version/) { (my $txt, $version) = split('Version ', $field); }
      }
    }
  }
}

################################################################################
# Example response for Cisco ASA 5520:
# "Cisco Adaptive Security Appliance Version 8.0(4)"
#                                            ^^^^^^
################################################################################
elsif ($opt_g =~ /asa/) {
  if($snmpdata =~ /^Cisco Adaptive Security Appliance.*/) {
    (my $os, $version) = split('Version ', $snmpdata);
  }
}

###############################################################################
# Example response for Cisco PIX 525:
# "Cisco PIX Firewall Version 6.3(5)"
# "Cisco Cisco PIX Security Appliance Version 7.2(2)"
# "Cisco Cisco PIX Security Appliance Version 8.0(2)"
###############################################################################
elsif ($opt_g =~ /pix/) {
  if($snmpdata =~ /.* PIX .*/) {
    (my $os, $version) = split('Version ', $snmpdata);
  }
}

else { usage("Unknown option parameter: $opt_g\. Use $PROGNAME -h for help\.\n"); }

################################################################################
# If the SNMP data cannot be parsed, we generate the exit code and finish.
################################################################################
if($version eq "") {
  printf("UNKNOWN: cannot find version string in SNMP response. Either -t <type> is incorrect or the Version string is unreadable.\n");
  exit $ERRORS{'UNKNOWN'};
}
################################################################################
# We are in 'discovery' mode, we report the OS Version, return 'OK' and finish.
################################################################################
elsif (! $opt_f) {
  printf (uc($opt_g)." Version: $version | $snmpdata\n");
  exit $ERRORS{'OK'};
}
################################################################################
# We are in 'compliance' mode, we check the OS Version against the config file
################################################################################
else {
  foreach my $line (@raw_data) {
    # skip comment lines
    next if($line =~ /^#.*$/);
    chomp($line);

    (my $required, my $osgroup, my $osversion, my $remarks)=split(/\|/,$line);

    if( ($opt_g eq $osgroup) && ($version eq $osversion) ) {

      if($required eq "approved") {
        $output = uc($opt_g)." Version: $version approved";
        if ($remarks ne "") { $output = $output." | Remarks: ".$remarks." Data: $snmpdata\n"; }
        else { $output = $output." | $snmpdata\n"; }
        printf $output; exit $ERRORS{'OK'};
      }

      if($required eq "obsolete") {
        $output = uc($opt_g)." Version: $version obsolete";
        if ($remarks ne "") { $output = $output." | Remarks: ".$remarks." Data: $snmpdata\n"; }
        else { $output = $output." | $snmpdata\n"; }
        printf $output; exit $ERRORS{'WARNING'};
      }

      if($required eq "med-vuln") {
        $output = uc($opt_g)." Version: $version vulnerable (low-medium)";
        if ($remarks ne "") { $output = $output." | Remarks: ".$remarks." Data: $snmpdata\n"; }
        else { $output = $output." | $snmpdata\n"; }
        printf $output; exit $ERRORS{'WARNING'};
      }

      if($required eq "crit-vuln") {
        $output = uc($opt_g)." Version: $version vulnerable (high risk)";
        if ($remarks ne "") { $output = $output." | Remarks: ".$remarks." Data: $snmpdata\n"; }
        else { $output = $output." | $snmpdata\n"; }
        printf $output; exit $ERRORS{'CRITICAL'};
      }
    }
  }
  # the OS version is not listed, we don't know exactly if its good or bad.
  printf (uc($opt_g)." Version: $version unverified | $snmpdata\n");
  exit $ERRORS{'UNKNOWN'};
}
################################################################################
# End of main. Subroutine definitions below.
################################################################################
sub read_config () {

  if (! -e $opt_f) { usage("Cannot find file $opt_f\. Check file name and path\.\n"); }
  open(DATFILE, $opt_f) || usage("Cannot read file $opt_f\. Check permissions\.\n");
  @raw_data=<DATFILE>;
  close(DATFILE);
}

sub print_usage () {
  print "Usage: $PROGNAME -H <host> [-v snmp version 1|2] -g <ios|asa|pix> [-C community] [-f <config file>]\n";
  exit $ERRORS{'OK'};
}

sub print_help () {
  print_revision($PROGNAME,'$Revision: 1.0.0 $');
  print "Copyright (c) 2009 Frank4DD

This plugin intends to report the OS version string of a supported vendor.
Currently it is parsing Cisco IOS, PIX and ASA versions through SNMP sysDescr polls.

In 'discovery mode' without using the option '-f', this plugin returns the OS
version string with 'OK' if the version could be fetched, or 'UNKNOWN' if not.
Useful if you need a view on what is out there in a enterprise environment.

In 'compliance mode' by specifying '-f', this plugin compares the device OS
version string against a list of categorized (approved) OS versions. It is
meant to identify devices running a rogue, obsolete or vulnerable OS version.

Usually this check runs only once in a couple of hours or even longer periods.
The configuration file format is in the check_snmp_patchlevel.cfg template.

";
	print_usage();
	print "
-H, --hostname=HOST
   Name or IP address of host to check
-v, --snmp-version [1|2]
   Specify the SNMP version to use: 1 or 2c
-g, --devicegroup=[ios|asa]
   OS version string to expect: ios = Cisco IOS Routers
				asa = Cisco ASA Appliances
                                pix = Cisco PIX Firewalls
-C, --community=community
   SNMP community (default public)
-f, --configfile=STRING
   Version file and path, contains a list of approved versions

";
  support();
  exit $ERRORS{'OK'};
}
