# Test to see if the Public Folders database is mounted on this server
# 
# The error handling is a little muddled coming back from the cmdlet
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
#check_publicfolders_mounted=cmd /c echo C:\Scripts\Nagios\PublicFoldersMounted.ps1 | PowerShell.exe -Command -
#
# On the check_nrpe command include the -t 20, since it takes some time to load
# the Exchange cmdlet's.

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010

$NagiosResult = "0"
try
	{
		try
			{
				$Result = Get-PublicFolder -Server $env:computername -ErrorAction Stop
				Write-Host "OK: Public folders are mounted."
			}
		catch [System.Management.Automation.ActionPreferenceStopException]
			{
				Throw $_.exception
			}
		catch
			{
				Throw $_.exception
			}
	} 
catch
	{
		Write-Host "CRITICAL: Public Folders Database is dismounted."
		$NagiosResult = "2"
	}

exit $NagiosResult
