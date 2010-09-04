# Test Replication Health
# 
# This script will execute the Test-ReplicationHealth command
# and look for warnings for failed replication attemtps
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Originally created by Jeff Roberson (jeffrey.roberson@gmail.com)
# at Bethel College, North Newton, KS
#
# Revision History
# 5/10/2010	Jeff Roberson		Creation
#
# To execute from within NSClient++
#
#[NRPE Handlers]
#check_replication_health=cmd /c echo C:\Scripts\Nagios\ReplicationHealth.ps1 | PowerShell.exe -Command -
#
# On the check_nrpe command include the -t 20, since it takes some time to load
# the Exchange cmdlet's.

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010

$NagiosStatus = "0"
$NagiosDescription = ""

ForEach ($Type in Test-ReplicationHealth -Identity $env:computername) {

 	# Look for failed replications
	if ($TypeResult -like "*FAILED*") {
		# Format the output for Nagios
		if ($NagiosDescription -ne "") {
			$NagiosDescription = $NagiosDescription + ", "
		}
		
		$NagiosDescription = $NagiosDescription + $Type.Check + $Type.Result
		
		# Set the status to failed.
		$NagiosStatus = "2"
		
	# Look for warnings in replication
	} elseif ($Type.Check -like "*Warn*") {
		# Format the output for Nagios
		if ($NagiosDescription -ne "") {
			$NagiosDescription = $NagiosDescription + ", "
		}
		
		$NagiosDescription = $NagiosDescription + $Type.Check + $Type.Result
		
		# Don't lower the status level if we already have
		# a failed attempt
		if ($NagiosStatus -ne "2") {
			$NagiosStatus = "1"
		}
	}
}

# Output, what level should we tell our caller?
if ($NagiosStatus -eq "2") {
	Write-Host "CRITICAL: " + $NagiosDescription
} elseif ($NagiosStatus -eq "1") {
	Write-Host "WARNING: " + $NagiosDescription
} else {
	Write-Host "OK: All replication tests passed."
}

exit $NagiosStatus

