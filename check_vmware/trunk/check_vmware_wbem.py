#!/usr/bin/python
#
# Copyright 2010, Pall Sigurdsson <palli@opensource.is>
#
# check_hpacucli.py is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# check_hpacucli.py is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# About this script
# 
# This script will check the status of Smart Array Raid Controller
# You will need the hpacucli binary in path (/usr/sbin/hpacucli is a good place)
# hpacucli comes with the Proliant Support Pack (PSP) from HP

debugging = False


# Some defaults
show_perfdata = True
show_longserviceoutput = True
uri='https://is-hdq-esx0:5989'
username='tommi'
password='tommi'
namespace='root/cimv2'


# No real need to change anything below here
version="1.0"
ok=0
warning=1
critical=2
unknown=3 
not_present = -1 
nagios_status = -1


state = {
	not_present : "n/a",
	ok          : "OK",
	warning     : "Warning",
	critical    : "Critical",
	unknown     : "Unknown",
}


longserviceoutput="\n"
perfdata=""
summary=""


from sys import exit
from sys import argv
from os import getenv,putenv,environ
import subprocess



def print_help():
        print "check_hpacucli version %s" % version
        print "This plugin checks HP Array with the hpacucli command"
        print ""
        print "Usage: %s " % argv[0]
        print "Usage: %s [--help]" % argv[0]
        print "Usage: %s [--version]" % argv[0]
        print "Usage: %s [--path </path/to/hpacucli>]" % argv[0]
        print "Usage: %s [--no-perfdata]" % argv[0]
        print "Usage: %s [--no-longoutput]" % argv[0]
        print  ""


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
	global show_longserviceoutput
	global show_perfdata
	if not show_perfdata:
		perfdata = ""
	print "%s - %s | %s" % (state[nagios_status], summary,perfdata)
	if show_longserviceoutput:
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




def run_hpacucli(type='controllers', controller=None):
	if type=='controllers':
		command="hpacucli  controller all show detail"
	elif type=='logicaldisks' or type=='physicaldisks':
		if controller.has_key('Slot'):
			identifier = 'slot=%s' % (controller['Slot'] )
		else:
			add_summary( "Controller not found" )
			end()
		if type=='logicaldisks':
			command = "hpacucli  controller %s ld all show detail" % (identifier)
		if type=='physicaldisks':
			command = "hpacucli  controller %s pd all show detail" % (identifier)
	
	#command="hpacucli  controller slot=1 ld all show detail"
	#command="hpacucli  controller slot=1 ld all show detail"
	debug ( command ) 
	output = runCommand(command)
	# Some basic error checking
	if output.find('Error: You need to have administrator rights to continue.') > -1:
		command = "sudo " + command 
		output = runCommand(command)
	output = output.split('\n')
	objects = []
	object = None
	for i in output:
		if len(i) == 0: continue
		if i.strip() == '': continue
		if type=='controllers' and i[0] != ' ': # No space on first line
			if object and not object in objects: objects.append(object)
			object = {}
			object['name'] = i
		elif type=='logicaldisks' and i.find('Logical Drive:') > 0:
			if object and not object in objects: objects.append(object)
			object = {}
			object['name'] = i.strip() 
		elif type=='physicaldisks' and i.find('physicaldrive') > 0:
			if object and not object in objects: objects.append(object)
			object = {}
			object['name'] = i.strip() 
		else:
			i = i.strip()
			if i.find(':') < 1: continue
			i = i.split(':')
			if i[0] == '': continue # skip empty lines
			if len(i) == 1: continue
			key = i[0].strip()
			value = ' '.join( i[1:] ).strip()
			object[key] = value
	if object and not object in objects: objects.append(object)
	return objects

controllers = []
def check_controllers():
	global controllers
	status = -1
	controllers = run_hpacucli()
	if len(controllers) == 0:
		add_summary("No Disk Controllers Found. Exiting...")
		global nagios_state
		nagios_state = unknown
		end()
	add_summary( "Found %s controllers" % ( len(controllers) ) )
	for i in controllers:
		controller_status = check(i, 'Controller Status', 'OK' )
		status = max(status, controller_status)
		
		cache_status = check(i, 'Cache Status' )
		status = max(status, cache_status)
		
		controller_serial = 'n/a'
		cache_serial = 'n/a'
		if i.has_key('Serial Number'):
			controller_serial = i['Serial Number']
		if i.has_key('Cache Serial Number'):
			cache_serial = i['Cache Serial Number']
		add_long ( "%s" % (i['name']) )
		add_long( "- Controller Status: %s (sn: %s)" % ( state[controller_status], controller_serial ) )
		add_long( "- Cache Status: %s (sn: %s)" % ( state[cache_status], cache_serial ) )

		if controller_status > ok or cache_status > ok:
			add_summary( ";%s on %s;" % (state[controller_status], i['name']) )

	add_summary(', ')	
	return status


def check_logicaldisks():
	global controllers
	if len(controllers) < 1:
		controllers = run_hpacucli()
	logicaldisks = []
	for controller in controllers:
		for ld in  run_hpacucli(type='logicaldisks', controller=controller):
			logicaldisks.append ( ld )
        status = -1
	add_long("\nChecking logical Disks:" )
        add_summary( "%s logicaldisks" % ( len(logicaldisks) ) )
	for i in logicaldisks:
		ld_status =  check(i, 'Status' )
		status = max(status, ld_status)
		
		mount_point = i['Mount Points']
		add_long( "- %s (%s) = %s" % (i['name'], mount_point, state[ld_status]) )
	add_summary(". ")

def check_physicaldisks():
        global controllers
	disktype='physicaldisks'
        if len(controllers) < 1:
                controllers = run_hpacucli()
        disks = []
        for controller in controllers:
                for disk in  run_hpacucli(type=disktype, controller=controller):
                        disks.append ( disk )
        status = -1
        add_long("\nChecking Physical Disks:" )
        add_summary( "%s %s" % ( len(disks), disktype ) )
        for i in disks:
                disk_status =  check(i, 'Status' )
                status = max(status, disk_status)

		size = i['Size']
		firmware = i['Firmware Revision']
		interface = i['Interface Type']
		serial = i['Serial Number']
		model = i['Model']
                add_long( "- %s, %s, %s = %s" % (i['name'], interface, size, state[disk_status]) )
		if disk_status > ok:
			add_long( "-- Replace drive, firmware=%s, model=%s, serial=%s" % (firmware,model, serial))
	if status > ok:
		add_summary( "(errors)" )
        add_summary(". ")


def check(object, field, valid_states = ['OK']):
	state = -1
	global nagios_status
	if object.has_key(field):
		if object[field] in valid_states:
			state = ok
		else:
			state = warning
	nagios_status = max(nagios_status, state)
	return state



def parse_arguments():
	global show_longserviceoutput
	global debugging
	global show_perfdata 
	global url
	global username
	global password
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
			debugging = True
		elif arg == '--longserviceoutput':
			show_longserviceoutput = True
		elif arg == '--no-longserviceoutput':
			show_longserviceoutput = False
		elif arg == '--perfdata':
			show_perfdata = True
		elif arg == '--no-perfdata':
			show_perfdata = False
		elif arg == '--uri':
			uri = arguments.pop(0)
		elif arg == '--hostname' or arg == '--host':
			hostname = arguments.pop(0)
			uri = 'https://%s:5989' % (hostname)
		elif arg == '--username':
			username = arguments.pop(0)
		elif arg == '--password':
			password = arguments.pop(0)
		else:
			print_help()
			exit(unknown)

# define classes to check 'OperationStatus' instance
ClassesToCheck = [
	'CIM_ComputerSystem',
	'CIM_NumericSensor',
	'CIM_Memory',
	'CIM_Processor',
	'CIM_RecordLog',
	'OMC_DiscreteSensor',
	'VMware_StorageExtent',
	'VMware_Controller',
	'VMware_StorageVolume',
	'VMware_Battery',
	'VMware_SASSATAPort'
]
		
import pywbem
import sys
def check_wbem():
	global ClassesToCheck
	global nagios_status
	debug( "Connetion to %s" % ( uri ) )	
	wbemclient = pywbem.WBEMConnection(uri, (username, password), namespace)
	
	for classe in ClassesToCheck :
		classe_status = not_present
		debug("Checking classe %s" %(classe) )
		instance_list = wbemclient.EnumerateInstances(classe)
		for instance in instance_list :
			elementName = instance['ElementName']
			for i in instance.keys():
				debug ( "%s %s = %s" %(elementName, i, instance[i]) )
			if instance['OperationalStatus'] is not None :
				elementStatus = instance['OperationalStatus'][0]
				debug( "Element %s = %s" % (elementName, elementStatus) )
				interpretStatus = {
					0  : ok,		# Unknown
					1  : critical,	# Other
					2  : ok,		# OK
					3  : warning,	# Degraded
					4  : warning,	# Stressed
					5  : warning,	# Predictive Failure
					6  : critical,	# Error
					7  : critical,	# Non-Recoverable Error
					8  : warning,	# Starting
					9  : warning,	# Stopping
					10 : critical,	# Stopped
					11 : ok,		# In Service
					12 : warning,	# No Contact
					13 : critical,	# Lost Communication
					14 : critical,	# Aborted
					15 : ok,		# Dormant
					16 : critical,	# Supporting Entity in Error
					17 : ok,		# Completed
					18 : ok,		# Power Mode
					19 : ok,		# DMTF Reserved
					20 : ok,		# Vendor Reserved
				}[elementStatus]
				nagios_status = max(nagios_status, interpretStatus)
				classe_status = max(classe_status, interpretStatus)
				if interpretStatus > ok:
					add_summary( "%s=%s" % (elementName, state[interpretStatus]) )
				add_long( "- %s=%s" % (elementName, state[interpretStatus]) )
		add_long( "%s = %s" % (classe, state[classe_status]) )

def main():
	parse_arguments()
	set_path('')
	check_wbem()
	#check_controllers()
	#check_logicaldisks()
	#check_physicaldisks()
	end()	


if __name__ == '__main__':
	main()
