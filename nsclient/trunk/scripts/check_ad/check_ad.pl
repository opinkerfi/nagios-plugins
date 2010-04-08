#####################
#
#	check_ad.pl - Nagios NRPE plugin to test Active Directory functionality
#
#	This plugin requires tools netdiag and dcdiag from Support Tools
#
#      This program is distributed under the Artistic License.
#      (http://www.opensource.org/licenses/artistic-license.php)
#	Copyright 2007-2009, Tevfik Karagulle, ITeF!x Consulting (http://itefix.no)

use strict;
use warnings;
use Getopt::Long;
use Win32;

our $VERSION = "1.4";

our $OK = 0;
our $WARNING = 1;
our $CRITICAL = 2;
our $UNKNOWN = 3;

our %status_text = (
	$OK => "OK",
	$WARNING => "WARNING",
	$CRITICAL => "CRITICAL",
	$UNKNOWN => "UNKNOWN"
);

our $is2000 = (Win32::GetOSName() eq 'Win2000');

our $member = 0;
our $dc = 0;
our $help = 0;
our $eventlog = 1; # take kccevent/frsevent into test set
our $kerbtest = 1; # take kerberos into test set 

GetOptions (
	"member" => \$member,  
	"dc"   => \$dc,
	"eventlog!" => \$eventlog,
	"kerberos!" => \$kerbtest,
	"help" => \$help
) || PrintUsage();

# Form netdiag/dcdiag command arguments
our $netdiagcmd = "netdiag /test:dns /test:dsgetdc /test:ldap";
our $dcdiagcmd = "dcdiag /test:services /test:replications /test:advertising /test:fsmocheck /test:ridmanager /test:machineaccount";

# add post-2000 spesific dcdiag tests
$dcdiagcmd .= (not $is2000) ? " /test:frssysvol" : "";
# add eventlog tests if requested
$dcdiagcmd .= ($eventlog) ? ($is2000 ? " /test:kccevent" : " /test:frsevent /test:kccevent") : "";
# add kerberos test if requested
$netdiagcmd .= ($kerbtest) ? " /test:kerberos" : "";

$member && MemberTests();
$dc && DcTests();
$help && PrintUsage();

#### SUBROUTINES ####

#### MemberTests ####
sub MemberTests
{
	open NETDIAG, "$netdiagcmd |" or ExitProgram ($UNKNOWN, "Could not open command pipe!");

	my ($member, $netbt, $dns, $dc, $kerberos, $ldap) = (0, 0, 0, 0, 0);

	my $warning = "";
	my $fatal = "";
	my $global_result = 0;

	while (<NETDIAG>)
	{
		chomp;	$_ = lc;
		
		$global_result = 1 if /global results:/; # Only interested in warning and/or fatal messages for global results.
	
		$member 	= 1 if /domain membership test . . . . . . : passed/;
		$netbt  	= 1 if /netbt transports test. . . . . . . : passed/;
		$dns 		= 1 if /dns test . . . . . . . . . . . . . : passed/;
		$dc 		= 1 if /dc discovery test. . . . . . . . . : passed/;
		$ldap 		= 1 if /ldap test. . . . . . . . . . . . . : passed/;
		$kerberos	= 1 if /kerberos test. . . . . . . . . . . . . : passed/ and $kerbtest;
	
		$warning	.= "$_  " if /warning/ and $global_result;
		$fatal		.= "$_  " if /fatal/ and $global_result;
	}

	my $status_ok = $member && $netbt && $dns && $dc && $ldap;
	$status_ok &&= $kerberos if $kerbtest;

	my $status_text = "Domain membership OK, NetBT transport OK, DNS OK, DC Discovery OK, LDAP OK";
	$status_text .= ", Kerberos OK" if $kerbtest;

	ExitProgram ($CRITICAL, $fatal) if $fatal ne "";
	ExitProgram ($WARNING, $warning) if $warning ne "";
	ExitProgram ($OK, $status_text)
		if  ($member && $netbt && $dns && $dc && $ldap);
	ExitProgram ($UNKNOWN, "No information is available.");
}

##### DcTests #####
sub DcTests
{
	open DCDIAG, "$dcdiagcmd |" or ExitProgram ($UNKNOWN, "Could not open command pipe!");

	my ($connectivity, $services, $replications, $advertising, $fsmo, $rid, $machine, $frssysvol, $frsevent, $kccevent) = 
		(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

	my $warning = "";
	my $fatal = "";

	while (<DCDIAG>)
	{
		chomp;	$_ = lc;
		
		$connectivity 	= 1 if /passed test connectivity/;
		$services	  	= 1 if /passed test services/;
		$replications	= 1 if /passed test replications/;
		$advertising	= 1 if /passed test advertising/;
		$fsmo	 		= 1 if /passed test fsmocheck/;
		$rid 			= 1 if /passed test ridmanager/;
		$machine 		= 1 if /passed test machineaccount/;
		$frssysvol 		= 1 if /passed test frssysvol/ and not $is2000;
		$frsevent		= 1 if /passed test frsevent/ and not $is2000;
		$kccevent		= 1 if /passed test kccevent/;
	
		$warning	.= "$_  " if /warning/;
		$fatal		.= "$_  " if /failed/;
	}

	my $status_ok = $connectivity && $services && $replications && $advertising && $fsmo && $rid && $machine;
	$status_ok &&= $frssysvol if not $is2000;
	$status_ok &&= $frsevent if not $is2000 and $eventlog;
	$status_ok &&= $kccevent if $eventlog;
	
	my $status_text = "Connectivity OK, Services OK, Replications OK, Advertising OK, Fsmo OK, Rid Manager OK, Machine account OK";
	$status_text .= ", FRS Sysvol OK" if not $is2000;
	$status_text .= ", FRS Event OK" if not $is2000 and $eventlog;
	$status_text .= ", KCC Event OK" if $eventlog;

	ExitProgram ($CRITICAL, $fatal) if $fatal ne "";
	ExitProgram ($WARNING, $warning) if $warning ne "";	
	ExitProgram ($OK, $status_text) if $status_ok;
	ExitProgram ($UNKNOWN, "No information is available.");
}

##### PrintUsage #####
sub PrintUsage
{
	print "
check_ad - Nagios NRPE Plugin for Active Directory Health Check
Version 1.4, Copyright 2007-2009, http://itefix.no

Usage:
    check_ad [--dc] [--member] [--noeventlog] [--nokerberos][--help]

Options:
    --dc
        Checks domain controller functionality by using dcdiag tool from
        Windows Support Tools. Following dcdiag tests are performed :

         services, replications, advertising, fsmocheck, ridmanager, machineaccount, kccevent, frssysvol (post-Windows 2000 only), frsevent (post-Windows 2000 only), 

    --member
        Checks domain member functionality by using netdiag tool from
        Windows Support Tools. Following netdiag tests are performed :

         member, netbt, dns, dsgetdc, ldap, kerberos

    --noeventlog
        Don't run the dc tests kccevent and frsevent, since their 24-hour
        scope may not be too relevant for Nagios.

    --nokerberos
        Don't run the member test kerberos due to netdiag bug (See Microsoft
        KB870692)

    --help
        Produces help message.


";
	
}

##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;
	
	my $lcomp = "AD";
	print "$lcomp $status_text{$exitcode} - $message";
	exit ($exitcode);
}

__END__

=head1 NAME

check_ad - Nagios NRPE plugin for Active Directory health check 

=head1 SYNOPSIS

B<check_ad> [B<--dc>] [B<--member>] [B<--noeventlog>] [B<--nokerberos>][B<--help>]

=head1 DESCRIPTION

B<check_ad> works as a Nagios NRPE plugin for Active Directory health check.

=head1 OPTIONS

=over 4 

=item B<--dc>

Checks domain controller functionality by using I<dcdiag> tool from Windows Support Tools. Following dcdiag tests are performed :

 services, replications, advertising, fsmocheck, ridmanager, machineaccount, kccevent, frssysvol (post-Windows 2000 only), frsevent (post-Windows 2000 only), 

=item B<--member>

Checks domain member functionality by using I<netdiag> tool from Windows Support Tools. Following netdiag tests are performed :

 member, netbt, dns, dsgetdc, ldap, kerberos

=item B<--noeventlog>

Don't run the dc tests kccevent and frsevent, since their 24-hour scope may not be too relevant for Nagios.

=item B<--nokerberos>

Don't run the member test kerberos due to netdiag bug (See Microsoft KB870692)

=item B<--help>

Produces help message.

=back

=head1 EXIT VALUES

 0 OK
 1 WARNING
 2 CRITICAL
 3 UNKNOWN

=head1 AUTHOR

Tevfik Karagulle L<http://www.itefix.no>

=head1 SEE ALSO

=over 4

=item Nagios web site L<http://www.nagios.org>

=item Nagios NRPE documentation L<http://nagios.sourceforge.net/docs/nrpe/NRPE.pdf>

=item DCDIAG documentation L<http://technet2.microsoft.com/windowsserver/en/library/f7396ad6-0baa-4e66-8d18-17f83c5e4e6c1033.mspx>

=item NETDIAG documentation L<http://technet2.microsoft.com/windowsserver/en/library/cf4926db-87ea-4f7a-9806-0b54e1c00a771033.mspx>

=back

=head1 COPYRIGHT

This program is distributed under the Artistic License. L<http://www.opensource.org/licenses/artistic-license.php>

=head1 VERSION

Version 1.4, January 2009

=head1 CHANGELOG

=over 4

=item changes from 1.3

 - Windows 2008 support (checks are done in lowercase only)
 - Dropped member test 'trust' as it requires domain admin privileges thus introducing a security weakness.
 - Introducing option 'nokerberos' due to netdiag bug (see Microsoft KB870692)

=item changes from 1.2

 - Add command line option 'noeventlog'.

=item changes from 1.1

 - Support for Windows 2000 domains
 - Use CRITICAL instead of ERROR

=item changes from 1.0

 - remove sysevent test as it can be many other event producers than active directory.

=back

=cut
