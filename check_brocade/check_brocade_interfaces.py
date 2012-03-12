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
def get_interface_statistics():
	interfaces = getTable('.1.3.6.1.4.1.1588.2.1.1.1.6.2.1')
	index = 1
	status = 4
	description = 36
	words_transmitted = 11
	words_received = 12
	frames_transmitted = 13
	frames_received = 14
	encoding_disparity_errors = 21
	crc_errors = 22
	truncated_frames = 23
	too_long_frames = 24
	bad_eof_frames = 25
	error_disparity_error = 26
	invalid_ordered_sets = 27
	discarded_class3_frames = 28
	timed_out_multicast_frames = 29
	
	bytes_transmitted = words_transmitted * 4
	bytes_received = words_received * 4
	concatted_counters = {}
	for i in interfaces.values():
		for k,v in i.items():
			if not concatted_counters.has_key( k ): concatted_counters[ k ] = 0
			#print concatted_counters[k]
			try: tmp = int( i[k] )
			except: continue
			#print k, v
			concatted_counters[k] = concatted_counters[k] + tmp
	add_perfdata("'Bad EOF Frames'=%sc" % ( concatted_counters[bad_eof_frames] ) )
	add_perfdata("'CRC Errors'=%sc" % ( concatted_counters[crc_errors] ) )
	add_perfdata("'Truncated Frames'=%sc" % ( concatted_counters[truncated_frames] ) )
	add_perfdata("'Too Long Frames'=%sc" % ( concatted_counters[too_long_frames] ) )
	add_perfdata("'Error/Disparity Error'=%sc" % ( concatted_counters[error_disparity_error] ) )
	add_perfdata("'Invalid Ordered sets received'=%sc" % ( concatted_counters[invalid_ordered_sets] ) )
	add_perfdata("'Discarded Class 3 Frames'=%sc" % ( concatted_counters[discarded_class3_frames] ) )
	add_perfdata("'Timed Out Multicast Frames'=%sc" % ( concatted_counters[timed_out_multicast_frames] ) )
	add_perfdata("'Encoding/Disparity Errors'=%sc" % ( concatted_counters[encoding_disparity_errors] ) )

	bytes_transmitted = concatted_counters[words_transmitted] * 4
	bytes_received =  concatted_counters[words_received] * 4 
	add_perfdata("'Bytes Transmitted'=%sc" % ( bytes_transmitted ) )
	add_perfdata("'Bytes Received'=%sc" % ( bytes_received) )
	nagios_status(ok)
	add_summary("%s interfaces found." % (len(interfaces) ) )
		
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
	get_interface_statistics()
	end()
