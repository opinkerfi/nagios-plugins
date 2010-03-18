#!/usr/bin/perl -w
#
# check_squid - Nagios check plugin for testing a Squid proxy
#
# Christoph Haas <email@christoph-haas.de>
# Andre Osti <andreoandre@gmail.com>
#
# License: GPL 2
#
# V0.2
#

require 5.004;
use POSIX;
use strict;
use Getopt::Long;
use vars qw($opt_V $opt_h $opt_t $opt_u $opt_n $opt_s
			$opt_p $opt_l $opt_o $opt_m $opt_e);
use vars qw($PROGNAME);
use lib "/usr/lib/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST GET);
use HTTP::Headers;
my ($url, $urluser, $urlpass, $proxy, $proxyport,
     $proxyuser, $proxypass, $expectstatus, $res, $req);

$PROGNAME = "check_squid_lw.pl";

sub print_help();
sub print_usage();

Getopt::Long::Configure('bundling');
GetOptions("V"   => \$opt_V, "version"    => \$opt_V,
	"h"   => \$opt_h, "help"         => \$opt_h,
	"t=s" => \$opt_t, "timeout=i"    => \$opt_t,
	"u=s" => \$opt_u, "url=s"        => \$opt_u,
	"n=s" => \$opt_n, "urluser=s"    => \$opt_n,
	"s=s" => \$opt_s, "urlpass=s"    => \$opt_s,
	"p=s" => \$opt_p, "proxy=s"      => \$opt_p,
	"l=s" => \$opt_l, "proxyport=s"  => \$opt_l,
	"o=s" => \$opt_o, "proxyuser=s"  => \$opt_o,
	"m=s" => \$opt_m, "proxypass=s"  => \$opt_m,
	"e=i" => \$opt_e, "status=i"     => \$opt_e);

if ($opt_V) {
    print_revision($PROGNAME,'$Revision: 0.1 $'); #'
    exit $ERRORS{'OK'};
}

if ($opt_h) {print_help(); exit $ERRORS{'OK'};}

($opt_u) || ($opt_u = shift) || usage("Use -h for more info\n");
$url = $opt_u;

($opt_p) || ($opt_p = shift) || usage("Use -h for more info\n");
$proxy = $opt_p;

($opt_l) || ($opt_l = shift) || usage("Use -h for more info\n");
$proxyport = $opt_l;

($opt_e) || ($opt_e = shift) || usage("Use -h for more info");
$expectstatus = $opt_e;

if(defined($opt_n)) { $urluser = $opt_n; }

if(defined($opt_s)) { $urlpass = $opt_s; }

if(defined($opt_o)) { $proxyuser = $opt_o; }

if(defined($opt_m)) { $proxypass = $opt_m; }

my $ua = new LWP::UserAgent;
my $h = HTTP::Headers->new();

if ($proxy)
{
        $ua->proxy(['http', 'ftp'], "http://$proxy:$proxyport");

        if ($proxyuser)
        {
                $h->proxy_authorization_basic($proxyuser,$proxypass);
        }
}

if ($urluser)
{
        $h->authorization_basic($urluser, $urlpass);
}

$req = HTTP::Request->new('GET', $url, $h);

$res = $ua->request($req);

if ($res->status_line =~ /^$expectstatus/)
{
        print "OK - Status: ".$res->status_line."\n";
		exit $ERRORS{"OK"};
}
else
{
        print "CRITICAL - Status: ".$res->status_line." (but expected $expectstatus...)\n";
		exit $ERRORS{"CRITICAL"};
}

sub print_usage () {
	print "Usage: $PROGNAME -u <internet site> -p <proxy> -l <port proxy> -e"; 
	print "<return http code> \n";
}

sub print_help () {
	print_revision($PROGNAME,'$Revision: 0.1 $');
	print "Perl check squid proxy\n";

	print_usage();

	print "
-V, --version
	Version this script
-h, --help
	Help
-t, --timeout=INTEGER
	default 15s
-u, --url=http://<site>
	 The URL to check on the internet (http://www.google.com)
-n, --urluser=username
	Username if the web site required authentication
-s, --urlpass=password
	Password if the web site required authentication
-p, --proxy=proxy
	Server that squid runs on (proxy.mydomain)
-l, --proxyport=INTEGER
	TCP port that Squid listens on (3128)
-o, --proxyuser=proxyuser
	Username if the web site required authentication
-m, --proxypass=proxypass
	Password if the web site required authentication
-e, --status=INTEGER
	HTTP code that should be returned

	";

	support();
}
