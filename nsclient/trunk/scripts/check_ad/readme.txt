NAME
   check_ad - Nagios NRPE plugin for Active Directory health check

SYNOPSIS
   check_ad [--dc] [--member] [--noeventlog] [--nokerberos][--help]

DESCRIPTION
   check_ad works as a Nagios NRPE plugin for Active Directory health check.

OPTIONS
   --dc
       Checks domain controller functionality by using *dcdiag* tool from
       Windows Support Tools. Following dcdiag tests are performed :

        services, replications, advertising, fsmocheck, ridmanager, machineaccount, kccevent, frssysvol (post-Windows 2000 only), frsevent (post-Windows 2000 only), 

   --member
       Checks domain member functionality by using *netdiag* tool from
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

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.no>

SEE ALSO
   Nagios web site <http://www.nagios.org>
   Nagios NRPE documentation
   <http://nagios.sourceforge.net/docs/nrpe/NRPE.pdf>
   DCDIAG documentation
   <http://technet2.microsoft.com/windowsserver/en/library/f7396ad6-0baa-4e6
   6-8d18-17f83c5e4e6c1033.mspx>
   NETDIAG documentation
   <http://technet2.microsoft.com/windowsserver/en/library/cf4926db-87ea-4f7
   a-9806-0b54e1c00a771033.mspx>

COPYRIGHT
   This program is distributed under the Artistic License.
   <http://www.opensource.org/licenses/artistic-license.php>

VERSION
   Version 1.4, January 2009

CHANGELOG
   changes from 1.3
        - Windows 2008 support (checks are done in lowercase only)
        - Dropped member test 'trust' as it requires domain admin privileges thus introducing a security weakness.
        - Introducing option 'nokerberos' due to netdiag bug (see Microsoft KB870692)

   changes from 1.2
        - Add command line option 'noeventlog'.

   changes from 1.1
        - Support for Windows 2000 domains
        - Use CRITICAL instead of ERROR

   changes from 1.0
        - remove sysevent test as it can be many other event producers than active directory.

