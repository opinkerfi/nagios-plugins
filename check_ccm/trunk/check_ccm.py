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

debugging = False



# No real need to change anything below here
version="1.0"
ok=0
warning=1
critical=2
unknown=3 
not_present = -1 
nagios_status = -1



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

required_gateways = []

def print_help():
	print "This is the help screen"
	pass


def error(errortext):
        print "* Error: %s" % errortext
        print_help()
        print "* Error: %s" % errortext
        exit(unknown)

def debug( debugtext ):
        global debugging
        if debugging:
                print  debugtext


'''runCommand: Runs command from the shell prompt. Exit Nagios style if unsuccessful'''
def runCommand(command):
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
	global nagios_status
        print "%s - %s | %s" % (state[nagios_status], summary,perfdata)
        print longserviceoutput
	if nagios_status < 0: nagios_status = unknown
        exit(nagios_status)

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



def parse_arguments():
	arguments = argv[1:]
	while len(arguments) > 0:
		arg = arguments.pop(0)
		if arg == '--help':
			print_help()
			exit(ok)
		elif arg == '--path':
			path = arguments.pop(0)
			set_path(path)
		elif arg == '--debug':
			global debugging
			debugging = True
		elif arg == '--mode':
			global mode
			mode = arguments.pop(0)
		elif arg == '--require_gateway':
			global required_gateways
			required_gateways.append( arguments.pop(0) )
		else:
			print_help()
			exit(unknown)

snmpgetcommand = "snmpget -v1 -c public 10.199.200.2 "

def snmpget(oid):
	output = runCommand(snmpgetcommand + " " + oid)
	oid,result = output.strip().split(' = ', 1)
	resultType,resultValue = result.split(': ',1)
	if resultType == 'STRING': # strip quotes of the string
		resultValue = resultValue[1:-1]
	return resultValue

def snmpwalk(base_oid):
	snmpwalkcommand = "snmpwalk -v1 -c public 10.199.200.2"
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
		
ccmGlobalInfoBase =			".1.3.6.1.4.1.9.9.156.1.5."
ccmActivePhones =			"1"
ccmInActivePhones =			"2"
ccmActiveGateways =			"3"
ccmInActiveGateways =			"4"
ccmRegisteredPhones =			"5"
ccmUnregisteredPhones =			"6"
ccmRejectedPhones =			"7"
ccmRegisteredGateways =			"8"
ccmUnregisteredGateways =		"9"
ccmRejectedGateways =			"10"
ccmRegisteredMediaDevices =		"11"
ccmUnregisteredMediaDevices =		"12"
ccmRejectedMediaDevices =		"13"
ccmRegisteredCTIDevices =		"14"
ccmUnregisteredCTIDevices =		"15"
ccmRejectedCTIDevices =			"16"
ccmRegisteredVoiceMailDevices =		"17"
ccmUnregisteredVoiceMailDevices =	"18"
ccmRejectedVoiceMailDevices =		"19"
ccmCallManagerStartTime =		"20"
ccmPhoneTableStateId =			"21"
ccmPhoneExtensionTableStateId =		"22"
ccmPhoneStatusUpdateTableStateId =	"23"
ccmGatewayTableStateId =		"24"
ccmCTIDeviceTableStateId =		"25"
ccmCTIDeviceDirNumTableStateId =	"26"
ccmPhStatUpdtTblLastAddedIndex =	"27"
ccmPhFailedTblLastAddedIndex =		"28"
ccmSystemVersion =			"29"
ccmInstallationId =			"30"
ccmPartiallyRegisteredPhones =		"31"
ccmH323TableEntries =			"32"
ccmSIPTableEntries =			"33"

def check_globalinfo():
	global nagios_status
	RegisteredPhones = snmpget( ".1.3.6.1.4.1.9.9.156.1.5.5.0" )
	UnRegisteredPhones = snmpget( ".1.3.6.1.4.1.9.9.156.1.5.6.0" )
	RejectedPhones = snmpget( ".1.3.6.1.4.1.9.9.156.1.5.7.0" )
	
	RegisteredGateways = snmpget( ".1.3.6.1.4.1.9.9.156.1.5.8.0" )
	UnRegisteredGateways = snmpget( ".1.3.6.1.4.1.9.9.156.1.5.9.0" )
	RejectedGateways = snmpget( ".1.3.6.1.4.1.9.9.156.1.5.10.0" )
	
	SIPTableEntries = snmpget( ".1.3.6.1.4.1.9.9.156.1.5.33.0" )

	nagios_status = max(nagios_status, ok)
	add_summary( "Registered phones: %s. " % (RegisteredPhones) )
	add_summary( "Registered Gateways: %s. " % (RegisteredGateways) )
	
	add_perfdata( "RegisteredPhones=%s UnRegisteredPhones=%s RejectedPhones=%s" % (RegisteredPhones,UnRegisteredPhones,RejectedPhones) )
	add_perfdata( "RegisteredGateways=%s UnRegisteredGateways=%s RejectedGateways=%s" % (RegisteredGateways,UnRegisteredGateways,RejectedGateways) )
	add_perfdata( "SIPTableEntries=%s " % (SIPTableEntries) )


def check_gateways():
	global required_gateways
	global nagios_status
	gateways = getTable('.1.3.6.1.4.1.9.9.156.1.3.1')
	name = 2
	gatewaytype = 3
	description = 4
	status = 5
	statusreason = 10
	friendlystatus= {
		"1":"unknown",
		"2":"registered",
		"3":"unregistered",
		"4":"rejected",
		"5":"partiallyregistered",
	}
	friendlystatusreason = {
		"0":"noError",
		"1":"unknown",
		"2":"noEntryInDatabase",
		"3":"databaseConfigurationError",
		"4":"deviceNameUnresolveable",
		"5":"maxDevRegReached",
		"6":"connectivityError",
		"7":"initializationError",
		"8":"deviceInitiatedReset",
		"9":"callManagerReset",
		"10":"authenticationError",
		"11":"invalidX509NameInCertificate",
		"12":"invalidTLSCipher",
		"13":"directoryNumberMismatch",
		"14":"malformedRegisterMsg",
	}
	num_down_gateways = 0
	gateway_names = []
	for i in gateways.values():
		nagios_status = max(nagios_status, ok)
		gateway_names.append( i[name] )
		if i[name] in required_gateways and i[status] != "2":
			nagios_status = max(nagios_status, critical)
			add_summary( "%s is %s (%s). " % ( i[name], friendlystatus[i[status]], friendlystatusreason[i[statusreason]] ) )
		if  friendlystatus[i[status]] != 'registered':
			num_down_gateways = num_down_gateways + 1
		add_long( "%s (%s) is %s (%s)" % ( i[name], i[description], friendlystatus[i[status]], friendlystatusreason[i[statusreason]] ) )
	add_summary( "%s out of %s gateways are up. " % ( (len(gateways)-num_down_gateways, len(gateways) ) ) )
	add_perfdata( "gateways_total=%s gateways_down=%s" % (len(gateways), num_down_gateways ) )
	for i in required_gateways:
		if i not in gateway_names:
			nagios_status = max(nagios_status, critical)
			add_summary( 'Gateway "%s" not found. ' % i )
	
def check_ccm():
	global nagios_status
	table = getTable('.1.3.6.1.4.1.9.9.156.1.1.2')
	ccmName = 2
	ccmDescription = 3
	ccmVersion = 4
	ccmStatus = 5
	ccmInetAddressType = 6
	id = ccmName

	friendlyCcmStatus = { "1":"unknown", "2":"up", "3":"down" }	
	for k,v in table.items():
		name = v[ccmName]
		status = v[ccmStatus]
		status = friendlyCcmStatus[status]
		if status == "up":
			nagios_status = max(nagios_status, ok)
		else:
			nagios_status = max(nagios_status, critical)
		add_summary( "%s is %s. " % (name,status) )
		add_long( "%s is %s" % (name, status) )
		add_long( "- version: %s" % (v[ccmVersion]) )
		add_long( "- description: %s" % (v[ccmDescription]) )
		add_long( "" )

def main():
	parse_arguments()
	global mode
	set_path('')
	if mode == None:
		check_ccm()
	elif mode == 'ccm_status':
		check_ccm()
	elif mode == 'globalinfo':
		check_globalinfo()
	elif mode == 'gateways':
		check_gateways()
	end()	


if __name__ == '__main__':
	main()
