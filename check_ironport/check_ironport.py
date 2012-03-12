#!/usr/bin/python
#
# Copyright 2010, Pall Sigurdsson <palli@opensource.is>
#
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# About this script
# 
# This script will check the status of a remote Cisco Call Manager via SNMP



# No real need to change anything below here
version="1.0"
ok=0
warning=1
critical=2
unknown=3 
not_present = -1 
exit_status = -1



state = {}
state[not_present] = "Not Present"
state[ok] = "OK"
state[warning] = "Warning"
state[critical] = "Critical"
state[unknown] = "Unknown"


longserviceoutput="\n"
perfdata=""
summary=""
sudo=False


from sys import exit
from sys import argv
from os import getenv,putenv,environ
import subprocess




# Parse some Arguments
from optparse import OptionParser
parser = OptionParser()
parser.add_option("-m","--mode", dest="mode",
	help="Which check mode is in use (powersupplies,licences,temp,raid,cpu,memory,openfiles)")
parser.add_option("-H","--host", dest="host",
	help="Hostname or IP address of the host to check")
parser.add_option("-w","--warning", dest="warning_threshold",
	help="Warning threshold", type="int", default=None)
parser.add_option("-c","--critical", type="int", dest="critical_threshold",
	help="Critical threshold", default=None)
parser.add_option("-e","--exclude", dest="exclude",
	help="Exclude specific object", default=None)
parser.add_option("-v","--snmp_version", dest="snmp_version",
	help="SNMP Version to use (1, 2c or 3)", default="3")
parser.add_option("-u","--snmp_username", dest="snmp_username",
	help="SNMP username (only with SNMP v3)", default=None)
parser.add_option("-C","--snmp_community", dest="snmp_community",
	help="SNMP Community (only with SNMP v1|v2c)", default=None)
parser.add_option("-p","--snmp_password", dest="snmp_password",
	help="SNMP password (only with SNMP v3)", default=None)
parser.add_option("-l","--snmp_security_level", dest="snmp_seclevel",
	help="SNMP security level (only with SNMP v3) (noAuthNoPriv|authNoPriv|authPriv)", default=None)
parser.add_option("-d","--debug", dest="debug",
	help="Enable debugging (for troubleshooting", action="store_true", default=False)

(opts,args) = parser.parse_args()


if opts.host == None:
	parser.error("Hostname (-H) is required.")
if opts.mode == None:
	parser.error("Mode (--mode) is required.")

snmp_options = ""
def set_snmp_options():
	global snmp_options
	if opts.snmp_version is not None:
		snmp_options = snmp_options + " -v%s" % opts.snmp_version
	if opts.snmp_version == "3":
		if opts.snmp_username is None:
			parser.error("--snmp_username required with --snmp_version=3")
		if opts.snmp_seclevel is None:
			parser.error("--snmp_security_level required with --snmp_version=3")
		if opts.snmp_password is None:
			parser.error("--snmp_password required with --snmp_version=3")
		snmp_options = snmp_options + " -u %s -l %s -A %s " % (opts.snmp_username, opts.snmp_seclevel,opts.snmp_password)
	else:
		if opts.snmp_community is None:
			parser.error("--snmp_community is required with --snmp_version=1|2c")
		snmp_options = snmp_options + " -c %s " % opts.snmp_community 

def error(errortext):
        print "* Error: %s" % errortext
        exit(unknown)

def debug( debugtext ):
        if opts.debug:
                print  debugtext

def nagios_status( newStatus ):
	global exit_status
	exit_status = max(exit_status, newStatus)
	return exit_status

'''runCommand: Runs command from the shell prompt. Exit Nagios style if unsuccessful'''
def runCommand(command):
  debug( "Executing: %s" % command )
  proc = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE,)
  stdout, stderr = proc.communicate('through stdin to stdout')
  if proc.returncode > 0:
    print "Error %s: %s\n command was: '%s'" % (proc.returncode,stderr.strip(),command)
    debug("results: %s" % (stdout.strip() ) )
    if proc.returncode == 127: # File not found, lets print path
        path=getenv("PATH")
        print "Check if your path is correct %s" % (path)
    if stderr.find('Password:') == 0 and command.find('sudo') == 0:
      print "Check if user is in the sudoers file"
    if stderr.find('sorry, you must have a tty to run sudo') == 0 and command.find('sudo') == 0:
      print "Please remove 'requiretty' from /etc/sudoers"
    exit(unknown)
  else:
    return stdout

def end():
	global summary
	global longserviceoutput
	global perfdata
	global exit_status
        print "%s - %s | %s" % (state[exit_status], summary,perfdata)
        print longserviceoutput
	if exit_status < 0: exit_status = unknown
        exit(exit_status)

def add_perfdata(text):
        global perfdata
        text = text.strip()
        perfdata = perfdata + " %s " % (text)

def add_long(text):
        global longserviceoutput
        longserviceoutput = longserviceoutput + text + '\n'

def add_summary(text):
	global summary
	summary = summary + text

def set_path(path):
	current_path = getenv('PATH')
	if current_path.find('C:\\') > -1: # We are on this platform
		if path == '':
			path = ";C:\Program Files\Hewlett-Packard\Sanworks\Element Manager for StorageWorks HSV"
			path = path + ";C:\Program Files (x86)\Compaq\Hpacucli\Bin"
			path = path + ";C:\Program Files\Compaq\Hpacucli\Bin"
		else: path = ';' + path
	else:	# Unix/Linux, etc
		if path == '': path = ":/usr/sbin"
		else: path = ':' + path
	current_path = "%s%s" % (current_path,path)
	environ['PATH'] = current_path



def snmpget(oid):
	snmpgetcommand = "snmpget %s %s %s" % (snmp_options,opts.host,oid)
	output = runCommand(snmpgetcommand)
	oid,result = output.strip().split(' = ', 1)
	resultType,resultValue = result.split(': ',1)
	if resultType == 'STRING': # strip quotes of the string
		resultValue = resultValue[1:-1]
	return resultValue

# snmpwalk -v3 -u v3get mgmt-rek-proxy-p02 -A proxy2011 -l authNoPriv 1.3.6.1.4.1.15497
def snmpwalk(base_oid):
	snmpwalkcommand = "snmpwalk %s %s %s" % (snmp_options, opts.host, base_oid)
	output = runCommand(snmpwalkcommand + " " + base_oid)
	return output

def getTable(base_oid):
	myTable = {}
	output = snmpwalk(base_oid)
	for line in output.split('\n'):
		tmp = line.strip().split(' = ', 1)
		if len(tmp) == 2:
			oid,result = tmp
		else:
			continue
		tmp = result.split(': ',1)
		if len(tmp) > 1:
			resultType,resultValue = tmp[0],tmp[1]
		else:
			resultType = None
			resultValue = tmp[0]
		if resultType == 'STRING': # strip quotes of the string
			resultValue = resultValue[1:-1]
		index = oid.strip().split('.')
		column = int(index.pop())
		row = int(index.pop())
		if not myTable.has_key(column): myTable[column] = {}
		myTable[column][row] = resultValue
	return myTable

def check_powersupplies():
	powersupplies = getTable('.1.3.6.1.4.1.15497.1.1.1.8.1')
	status = 2
	redundancy = 3
	name = 4
	friendlyStatus = {
		"1":"Power Supply Not Installed",
		"2":"Healthy",
		"3":"No AC",
		"4":"Faulty",
	}
	friendlyRedundancy = {
		"1":"Redundancy OK",
		"2":"Redundancy Lost",
	}
	num_ok = 0
	for i in powersupplies.values():
		myName = i[name]
		myStatus = friendlyStatus[ i[status] ]
		myRedundancy = friendlyRedundancy[ i[redundancy] ]
		if myName == opts.exclude: continue
		if myStatus != "Healthy":
			nagios_status(warning)
			add_summary( 'Powersupply "%s" status "%s". %s. ' % (myName,myStatus,myRedundancy) )
		else:
			num_ok = num_ok + 1
		if myRedundancy != "Redundancy OK":
			nagios_status( warning )
		add_long('Powersupply "%s" status "%s". %s. ' % (myName,myStatus,myRedundancy) )
	add_summary( "%s out of %s power supplies are healthy" % (num_ok, len(powersupplies) ) )
	add_perfdata( "'Number of powersupplies'=%s" % (len(powersupplies) ) )
		
	nagios_status(ok)

def check_licences():
	keys = getTable('.1.3.6.1.4.1.15497.1.1.1.12.1')
	
	for i in keys.values():
		description = i[2]
		perpetual = i[3]
		secondsuntilexpire = int( i[4] )
		if description == opts.exclude: continue
		if perpetual == "1":
			expires="never expires"
		elif secondsuntilexpire == 0:
			expires="is expired"
			nagios_status(critical)
			add_summary( "%s %s" % (description, expires))
		else:
			expires="expires in %s seconds" % ( secondsuntilexpire )
			if opts.warning_threshold is not None and secondsuntilexpire < opts.warning_threshold:
				nagios_status(warning)
				add_summary( "%s %s" % (description, expires))
		add_long( "* %s - %s." % (description, expires) )
	tmp = nagios_status(ok)
	if tmp == ok:
		add_summary( "All %s licences are ok" % ( len(keys) ) )

def check_temperature():
	# set some sensible defaults
	if opts.warning_threshold is None: opts.warning_threshold = 28
	if opts.critical_threshold is None: opts.critical_threshold = 35
	sensors = getTable('.1.3.6.1.4.1.15497.1.1.1.9.1')
	name = 3
	degreesCelsius = 2
	for sensor in sensors.values():
		degrees = int(sensor[degreesCelsius])
		sensorname = sensor[name]
		if sensorname == opts.exclude: continue
		if opts.critical_threshold is not None and degrees > opts.critical_threshold:
			nagios_status(critical)
			add_summary( "%s temperature (%s celsius) is over critical thresholds (%s). " % (sensorname, degrees, opts.critical_threshold) )
		elif opts.warning_threshold is not None and degrees > opts.warning_threshold:
			nagios_status(warning)
			add_summary( "%s temperature (%s celsius) is over warning thresholds (%s). " % (sensorname, degrees,opts.warning_threshold) )
		else:
			add_summary( "%s = %s degrees. " % (sensorname, degrees) )
		add_perfdata( "'%s'=%s " % (sensorname, degrees) )
		add_long( "Temperature %s = %s (celsius)" % (sensorname, degrees) )
	nagios_status(ok)

def check_cpu():
	if opts.warning_threshold is None: opts.warning_threshold = 90
	if opts.critical_threshold is None: opts.critical_threshold = 101
	cpu = snmpget(".1.3.6.1.4.1.15497.1.1.1.2.0")
	cpu = int(cpu)
	if cpu > opts.warning_threshold:
		nagios_status(warning)
	if cpu > opts.critical_threshold:
		nagios_status(critical)
	nagios_status(ok)
	add_summary("CPU Utilization=%s%% (warning=%s,critical=%s)" % (cpu,opts.warning_threshold,opts.critical_threshold) )
	add_perfdata("'CPU Utilization'=%s%%;%s;%s " %  (cpu,opts.warning_threshold,opts.critical_threshold) )

def check_openfiles():
        #if opts.warning_threshold is None: opts.warning_threshold = 90
        #if opts.critical_threshold is None: opts.critical_threshold = 101
        files = snmpget(".1.3.6.1.4.1.15497.1.1.1.19.0")
        files = int(files)
        if opts.warning_threshold and files > opts.warning_threshold:
                nagios_status(warning)
        if opts.critical_threshold and files > opts.critical_threshold:
                nagios_status(critical)
        nagios_status(ok)
        add_summary("Open files and sockets: %s (warning=%s,critical=%s)" % (files,opts.warning_threshold,opts.critical_threshold) )
	if not opts.warning_threshold: opts.warning_threshold = 0
	if not opts.critical_threshold: opts.critical_threshold = 0
        add_perfdata("'Open Files'=%s;%s;%s " %  (files,opts.warning_threshold,opts.critical_threshold) )


def check_memory():
        if opts.warning_threshold is None: opts.warning_threshold = 95
        if opts.critical_threshold is None: opts.critical_threshold = 101
        mem = snmpget(".1.3.6.1.4.1.15497.1.1.1.1.0")
        mem = int(mem)
        if mem > opts.warning_threshold:
                nagios_status(warning)
        if mem > opts.critical_threshold:
                nagios_status(critical)
        nagios_status(ok)
        add_summary("Memory Utilization=%s%% (warning=%s,critical=%s)" % (mem,opts.warning_threshold,opts.critical_threshold) )
        add_perfdata("'Memory Utilization'=%s%%;%s;%s " %  (mem,opts.warning_threshold,opts.critical_threshold) )


def check_raid():
	drives = getTable('.1.3.6.1.4.1.15497.1.1.1.18.1')
	status = 2
	raidID = 3
	raidLastError = 4
	friendlyRaidStatus = {
		"1":"driveHealthy",
		"2":"driveFailure",
		"3":"driveRebuild",
	}
	num_healthy_drives = 0
	for i in drives.values():
		driveStatus = i[status]
		driveStatus = friendlyRaidStatus[ driveStatus ]
		if i[raidID] == opts.exclude: continue
		if driveStatus == 'driveHealthy':
			nagios_status(ok)
			num_healthy_drives = num_healthy_drives + 1
		elif driveStatus == 'driveFailure':
			nagios_status(critical)
			add_summary( '"%s" has failed (%s). ' % ( i[raidID], i[raidLastError] ) )
		elif driveStatus == 'driveRebuild':
			nagios_status(warning)
			add_summary( '"%s" is rebuilding (%s). ' % ( i[raidID], i[raidLastError] ) )
		else: print driveStatus
		add_long( '"%s" - %s (%s) ' % (i[raidID], driveStatus, i[raidLastError]) )
	add_summary( "%s out of %s drives are healthy" % (num_healthy_drives, len(drives) ) )
	nagios_status(ok)
	
	
		

if __name__ == '__main__':
	set_snmp_options()
	if opts.mode == 'powersupplies':
		check_powersupplies()
	elif opts.mode == 'licences':
		check_licences()
	elif opts.mode == 'temp':
		check_temperature()
	elif opts.mode == 'raid':
		check_raid()
	elif opts.mode == 'cpu':
		check_cpu()
	elif opts.mode == 'memory':
		check_memory()
	elif opts.mode == 'openfiles':
		check_openfiles()
	else:
		parser.error("%s is not a valid option for --mode" % opts.mode)
	end()
