#!/usr/bin/python
#
# Copyright 2010, Pall Sigurdsson <palli@opensource.is>
#
# check_eva.py is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# check_eva.py is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# About this script
# 
# This script will check the status of all EVA arrays via the sssu binary.
# You will need the sssu binary in path (/usr/bin/sssu is a good place)
# If you do not have sssu, check your commandview CD, it should have both
# binaries for Windows and Linux






# Some Defaults
show_perfdata = True
show_longserviceoutput = True
debugging = False



# check_eva defaults
hostname="localhost"
username="eva"
password="eva1234"
mode="check_systems"
path=''
nagios_server = ""
nagios_port = 8002
nagios_myhostname = "localhost"
escape_newlines = False

# No real need to change anything below here
version="1.0"
ok=0
warning=1
critical=2
unknown=3
not_present = -1



state = {}
state[not_present] = "Not Present"
state[ok] = "OK"
state[warning] = "Warning"
state[critical] = "Critical"
state[unknown] = "Unknown"

longserviceoutput="\n"
perfdata=""

valid_modes = ( "check_systems", "check_controllers", "check_diskgroups","check_disks", "check_diskshelfs")

from sys import exit
from sys import argv
from os import getenv,putenv
import subprocess
import xmlrpclib
import socket
socket.setdefaulttimeout(5) 


def print_help():
	print "check_eva version %s" % version
	print "This plugin checks HP EVA Array with the sssu command"
	print ""
	print "Usage: %s [OPTIONS]" % argv[0]
	print "OPTIONS:"
	print  " [--host <host>]"
	print  " [--username <user>]"
	print  " [--password <password]"
	print  " [--path </path/to/sssu>]"
	print  " [--mode <mode>] "
	print  " [--test]"
	print  " [--debug]"
	print  " [--help]"
	print  ""
	print  " Valid modes are: %s" % ', '.join(valid_modes)
	print  ""
	print  "Example: %s --host commandview.example.net --username eva --password myPassword --mode check_systems" % (argv[0])


def error(errortext):
	print "* Error: %s" % errortext
	print_help()
	print "* Error: %s" % errortext
	exit(unknown)

def debug( debugtext ):
	global debugging
	if debugging:
		print  debugtext

# parse arguments

arguments=argv[1:]
while len(arguments) > 0:
	arg=arguments.pop(0)
	if arg == 'invalid':
		pass
	elif arg == '-H' or arg == '--host':
		hostname=arguments.pop(0)
	elif arg == '-U' or arg == '--username':
		username=arguments.pop(0)
	elif arg == '-P' or arg == '--password':
		password = arguments.pop(0)
	elif arg == '-T' or arg == '--test':
		testmode=1
	elif arg == '--path':
		path = arguments.pop(0) + '/'
	elif arg == '-M' or arg == '--mode':
		mode=arguments.pop(0)
		if mode not in valid_modes:
			error("Invalid --mode %s" % arg)
	elif arg == '-d' or arg == '--debug':
		debugging=True
	elif arg == '--longserviceoutput':
		show_longserviceoutput = True
	elif arg == '--no-longserviceoutput':
		show_longserviceoutput = False
	elif arg == '--perfdata':
		show_perfdata = True
	elif arg == '--no-perfdata':
		show_perfdata = False
	elif arg == '--nagios_myhostname':
		nagios_myhostname = arguments.pop(0)
	elif arg == '--nagios_server':
		nagios_server = arguments.pop(0)
	elif arg == '--nagios_port':
		nagios_port = arguments.pop(0)
	elif arg == '--escape-newlines':
		escape_newlines = True
	elif arg == '-h' or '--help':
		print_help()
		exit(ok)
	else:
		error( "Invalid argument %s"% arg)




subitems = {}
subitems['fan'] = 'fans'
subitems['source'] = 'powersources'
subitems['hostport'] = 'hostports'
subitems['module'] = 'modules'
subitems['sensor'] = 'sensors'
subitems['powersupply'] = 'powersupplies'
subitems['bus'] = 'communicationbuses'
subitems['port'] = 'fibrechannelports'


'''runCommand: Runs command from the shell prompt. Exit Nagios style if unsuccessful'''
def runCommand(command):
  proc = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE,)
  stdout, stderr = proc.communicate('through stdin to stdout')
  if proc.returncode > 0:
    print "Error %s: %s\n command was: '%s'" % (proc.returncode,stderr.strip(),command)
    if proc.returncode == 127: # File not found, lets print path
	path=getenv("PATH")
	print "Current Path: %s" % (path)
    exit(unknown)
  else:
    return stdout




'''Runs the sssu command. This one is responsible for error checking from sssu'''
def run_sssu(system=None, command="ls system full"):
	commands = []

	continue_on_error="set option on_error=continue"
	login="select manager %s USERNAME=%s PASSWORD=%s"%(hostname,username,password)

	commands.append(continue_on_error)
	commands.append(login)
	if system != None:
		commands.append("select SYSTEM %s" % system)
	commands.append(command)

	commandstring = "sssu "
	for i in commands: commandstring = commandstring + '"%s" '% i 
	
	#print mystring
	#if command == "ls system full":
	#	output = runCommand("cat sssu.out")
	#elif command == "ls disk_groups full":
	#	output = runCommand("cat ls_disk*")
	#elif command == "ls controller full":
	#	output = runCommand("cat ls_controller")
	#else:
	#	print "What command is this?", command
	#	exit(unknown)
	output = runCommand(commandstring)
	debug( commandstring )

	output = output.split('\n')

	# Lets process the top few results from the sssu command. Make sure the results make sense
	error = 0
	if output.pop(0).strip() != '': error = 1
	if output.pop(0).strip() != '': error = 1
	if output.pop(0).strip() != 'SSSU for HP StorageWorks Command View EVA': error = 1
	if output.pop(0).strip().find('Version:') != 0: error=1
	if output.pop(0).strip().find('Build:') != 0: error=1
	if output.pop(0).strip().find('NoSystemSelected> ') != 0: error=1
	#if output.pop(0).strip() != '': error = 1
	#if output.pop(0).strip().find('NoSystemSelected> ') != 0: error=1
	#if output.pop(0).strip() != '': error = 1
	buffer = ""
	for i in output:
		buffer = buffer + i + "\n"
		if i.find('Error') > -1:
			print "This is the command i was trying to execute: %s" % i
			error = 1
		if i.find('information:') > 0: break
	if error > 0: 
		print "Error running the sssu command"
		print commandstring
		print buffer
		exit(unknown)
	
	objects = []
	object = None
	parent_object = None
	for line in output:
		if len(line) == 0:
			continue
		line = line.strip()
		tmp = line.split()
		if len(tmp) == 0:
			if object:
				if not object['master'] in objects: objects.append( object['master'] )
				object = None
			continue
		key = tmp[0].strip()
		if object and not object['master'] in objects: objects.append( object['master'] )
		if key == 'object':
			object = {}
			object['master'] = object
		if key == 'controllertemperaturestatus':
			object = object['master']
		if key == 'iomodules':
			key = 'modules'
		#if key in subitems.values():
		#	object['master'][key] = []
		if key in subitems.keys():
			mastergroup = subitems[key]
			master = object['master']
			object = {}
			object['object_type'] = key
			object['master'] = master
			if not object['master'].has_key(mastergroup):
				object['master'][mastergroup] = []
			object['master'][mastergroup].append(object)
			
			

		if line.find('.:') > 0:
			# We work on first come, first serve basis, so if 
			# we accidentally see same key again, we will ignore
			if not object.has_key(key):
				value = ' '.join( tmp[2:] ).strip()
				object[key] = value
	#for i in objects:
	#	print i['objectname']
	return objects

def end(summary,perfdata,longserviceoutput,nagios_state):
	global show_longserviceoutput
	global show_perfdata
	global nagios_server
	global nagios_port
	global nagios_myhostname
	global hostname
	global mode
	global escape_newlines

	message = "%s - %s" % ( state[nagios_state], summary)
	if show_perfdata:
		message = "%s | %s" % ( message, perfdata)
	if show_longserviceoutput:
		message = "%s\n%s" % ( message, longserviceoutput.strip())
	if escape_newlines == True:
		lines = message.split('\n')
		message = '\\n'.join(lines)
	if nagios_server is not None:
		try:
			phone_home(nagios_server,nagios_port, status=nagios_state, message=message, hostname=nagios_myhostname, servicename=mode)
		except:
			pass
	print message
	exit(nagios_state)

''' phone_home: Sends results to remote nagios server via python xml-rpc '''
def phone_home(nagios_server,nagios_port, status, message, hostname=None, servicename=None):
	uri = "http://%s:%s" % (nagios_server,nagios_port)
	s = xmlrpclib.ServerProxy( uri )
	s.nagiosupdate(hostname, servicename, status, message)
	return 0

def check_systems():
	summary=""
	perfdata=""
	#longserviceoutput="\n"
	nagios_state = ok
	objects = run_sssu()
	for i in objects:
		name = i['objectname']
		operationalstate = i['operationalstate']
		# Lets see if this array is working
		if operationalstate != 'good':
			nagios_state = max(nagios_state, warning)
		# Lets add to the summary
		summary = summary + " %s=%s " %(name, operationalstate)
		# Collect the performance data
		interesting_perfdata = 'totalstoragespace|usedstoragespace|availablestoragespace'
		perfdata = perfdata + get_perfdata(i,interesting_perfdata.split('|'), identifier="%s_"% name)
		# Collect extra info for longserviceoutput
		long("%s = %s (%s)\n" % ( i['objectname'], i['operationalstate'], i['operationalstatedetail']) )
		interesting_fields = 'licensestate|systemtype|firmwareversion|nscfwversion|totalstoragespace|usedstoragespace|availablestoragespace'
		for x in interesting_fields.split('|'):
			long( "- %s = %s \n" %(x, i[x]) )
		long("\n")
	end(summary,perfdata,longserviceoutput,nagios_state)



def get_perfdata(object, interesting_fields, identifier=""):
	perfdata = ""
	for i in interesting_fields:
		if i == '': continue
		perfdata = perfdata + "'%s%s'=%s " % (identifier, i, object[i])
	return perfdata

def add_perfdata(text):
	global perfdata
	text = text.strip()
	perfdata = perfdata + " %s " % (text)

def long(text):
	global longserviceoutput
	longserviceoutput = longserviceoutput + text
def get_longserviceoutput(object, interesting_fields):
	longserviceoutput = ""
	for i in interesting_fields:
		longserviceoutput = longserviceoutput + "%s = %s \n" %(i, object[i])
	return longserviceoutput

def check_operationalstate(object, print_failed_objects=False,namefield='objectname',detailfield='operationalstatedetail',statefield='operationalstate',valid_states=['good']):
	if not object.has_key(detailfield): detailfield = statefield
	if object['operationalstate'] not in valid_states:
		if print_failed_objects:
			long("Warning, %s=%s (%s)\n" % ( object[namefield], object['operationalstate'], object[detailfield] ))
		return warning
	debug( "OK, %s=%s (%s)\n" % ( object[namefield], object['operationalstate'], object[detailfield] ) )
	return ok



def check_generic(command="ls disk full",namefield="objectname", perfdata_fields=[], longserviceoutputfields=[], detailedsummary=False):
        summary=""
	global perfdata
        nagios_state = ok
        systems = run_sssu()
        objects = []
	if command == 'ls system full':
		objects = systems
		for i in systems: i['systemname'] = '' #i['objectname']
	else:
        	for i in systems:
        	        result = run_sssu(system=i['objectname'], command=command)
        	        for x in result:
        	                x['systemname'] = i['objectname']
        	                objects.append( x )
	summary = "%s objects found " % len(objects)
        for i in objects:
                systemname = i['systemname']
                objectname = i[namefield]
                
		# Lets see if this object is working
                nagios_state = max( check_operationalstate(i), nagios_state )

                
		# Lets add to the summary
		if  i['operationalstate'] != 'good' or detailedsummary == True:
                	summary = summary + " %s/%s=%s " %(systemname,objectname, i['operationalstate'])

                # Lets get some perfdata
                identifier = "%s/%s_" % (systemname,objectname)
		i['identifier'] = identifier


		for field in perfdata_fields:
			if field == '': continue
			add_perfdata( "'%s%s'=%s " % (identifier, field, i[field]) )
		
		# Disk group gets a special perfdata treatment
		if command == "ls disk_group full":
			totalstoragespacegb= float( i['totalstoragespacegb'] )
			usedstoragespacegb= float ( i['usedstoragespacegb'] )
			occupancyalarmlvel = float( i['occupancyalarmlevel'] ) 
			warninggb= totalstoragespacegb * occupancyalarmlvel / 100
			add_perfdata( " '%sdiskusage'=%s;%s;%s "% (identifier, usedstoragespacegb,warninggb,totalstoragespacegb) )
		
                # Long Serviceoutput
		
		# There are usually to many disks for nagios to display. Skip.
		if command != "ls disk full":
			long( "\n%s/%s = %s (%s)\n"%(systemname,objectname,i['operationalstate'], i['operationalstatedetail']) )
		
		# If diskgroup has a problem because it is over allocated. Lets inform about that
		if command == "ls disk_group full" and usedstoragespacegb > warninggb:
				long("- %s - diskgroup usage is over %s%% threshold !\n" % (state[warning], occupancyalarmlvel) )
		# If a disk has a problem, lets display some extra info on it
		elif command == "ls disk full" and i['operationalstate'] != 'good':
			long( "Warning - %s=%s (%s)\n" % (i['diskname'], i['operationalstate'], i['operationalstatedetail'] ))
			fields="modelnumber firmwareversion serialnumber failurepredicted  diskdrivetype".split()
			for field in fields:
				long( "- %s = %s\n" % (field, i[field]) )


		nagios_state = max(nagios_state, check_multiple_objects(i, 'sensors'))
		nagios_state = max(nagios_state, check_multiple_objects(i, 'fans'))
		nagios_state = max(nagios_state, check_multiple_objects(i, 'powersupplies'))
		nagios_state = max(nagios_state, check_multiple_objects(i, 'communicationbuses'))
		nagios_state = max(nagios_state, check_multiple_objects(i, 'fibrechannelports'))
		nagios_state = max(nagios_state, check_multiple_objects(i, 'modules'))
                for x in longserviceoutputfields:
                        long( "- %s = %s\n" % (x, i[x]))

        end(summary,perfdata,longserviceoutput,nagios_state)

def check_multiple_objects(object, name):
	item_status = not_present
	if object.has_key(name): 
		item_status = not_present
		valid_states=['good']
		namefield="name"	
		detailfield = 'operationalstatedetail'



		if name == 'fans' or name == 'sensors':
			valid_states = ['good','notavailable','unsupported','notinstalled']
		num_items = len(object[name])
		for item in object[name]:
			stat = check_operationalstate( item,print_failed_objects=True, namefield=namefield, valid_states=valid_states,detailfield=detailfield)
			item_status = max( stat, item_status )
		long('- %s on %s (%s detected)\n'% (state[item_status], name, num_items) )
		add_perfdata( " '%s%s'=%s" % (object['identifier'],name, num_items) )
	return item_status
	


def check_controllers():
	summary=""
	perfdata=""
	#longserviceoutput="\n"
	nagios_state = ok
	systems = run_sssu()
	controllers =[]
	for i in systems:
		result = run_sssu(system=i['objectname'], command="ls controller full")
		for controller in result:
			controller['systemname'] = i['objectname']
			controllers.append( controller )
	for i in controllers:
		systemname = i['systemname']
		controllername = i['controllername']
		# Lets see if this controller is working
		nagios_state = max( check_operationalstate(i), nagios_state )

		# Lets add to the summary
		summary = summary + " %s/%s=%s " %(systemname,controllername, i['operationalstate'])
		
		# Lets get some perfdata
		interesting_fields = "controllermainmemory"
		identifier = "%s/%s_" % (systemname,controllername)
		perfdata = perfdata + get_perfdata(i, interesting_fields.split('|'), identifier=identifier)

		# Long Serviceoutput
		interesting_fields = "operationalstate|operationalstatedetail|firmwareversion|serialnumber"
		#longserviceoutput = longserviceoutput + get_longserviceoutput(i, interesting_fields.split('|') )
		#longserviceoutput = longserviceoutput + "\n%s/%s\n"%(systemname,controllername)
		long( "\n%s/%s = %s (%s)\n"%(systemname,controllername,i['operationalstate'], i['operationalstatedetail']) )
		long( "- firmwareversion = %s \n" %(i['firmwareversion']))
		long( "- serialnumber = %s \n" %(i['serialnumber']))


		controllertemperaturestatus = not_present
		cache_state = not_present
		fanstate = not_present
		hostportstate = not_present
		sensorstate = ok
		source_state = not_present
		module_state = not_present

		# Check the cache status
		if i['cachecondition'] == 'good':
			cache_state = ok
		else:
			cache_state = warning
		
		# Check Temperature
		if i.has_key("controllertemperaturestatus"):
			if i['controllertemperaturestatus'] == 'normal':
				controllertemperaturestatus = ok
			else:
				controllertemperaturestatus = warning
		
		
		# Process the subsensors
		for hostport in i['hostports']:
			#long(" %s = %s\n" % (hostport['portname'], hostport['operationalstate']))
			hostportstate = max(hostportstate,ok)
			if hostport['operationalstate'] != 'good':
				hostportstate = max(warning,hostport_state)
				long("Hostport %s state = %s\n" % hostport['portname'], hostport['operationalstate'])
		if i.has_key('fans'):
			for fan in i['fans']:
				fanstate = max(fanstate,ok)
				#long(" %s = %s\n" % (fan['fanname'], fan['status']))
				if fan.has_key('status'): status = fan['status']
				elif fan.has_key('installstatus'): status = fan['installstatus']
				if status != 'normal' and status != 'yes':
					fanstate = max(warning,fanstate)
					long("Fan %s status = %s\n" % (fan['fanname'],status))
		if i.has_key('powersources'):
			for source in i['powersources']:
				source_state = max(source_state,ok)
				if not source.has_key('status'): continue
				if source['state'] != 'good':
					source_state = max(warning,source_state)
					long("Powersource %s status = %s\n" % (source['type'],source['state']))
		if i.has_key('modules'):
			for module in i['modules']:
				module_state = max(module_state,ok)
				if module['operationalstate'] not in ('good','not_present'):
					module_state = max(warning,module_state)
					long("Battery Module %s status = %s\n" % (module['name'],module['operationalstate']))
		

		for i in (fanstate,hostportstate,sensorstate,source_state,module_state,cache_state,controllertemperaturestatus):
			nagios_state = max(nagios_state, i)
	
		long("- %s on fans\n"%( state[fanstate] ) )
		long("- %s on cachememory\n"%( state[cache_state] ) )
		long("- %s on temperature\n"%( state[controllertemperaturestatus] ) )
		long("- %s on hostports\n"%( state[hostportstate] ) )
		long("- %s on sensors\n"%( state[sensorstate] ) )
		long("- %s on powersupplies\n"%( state[source_state] ) )
		long("- %s on batterymodules\n"%( state[module_state] ) )
			
			
		long('\n')
	end(summary,perfdata,longserviceoutput,nagios_state)

def set_path():
	global path
	current_path = getenv('PATH')
	if path == '':
		if current_path.find('C:\\') > -1: # We are on this platform
			path = "C:\\Program Files\\Hewlett-Packard\\Sanworks\\Element Manager for StorageWorks HSV"
		else:
			path = "/usr/local/bin"
	current_path = "%s:%s" % (current_path,path)
	putenv('PATH', current_path)
set_path()



if mode == 'check_systems':
                perfdata_fields = 'totalstoragespace usedstoragespace availablestoragespace'.split()
                longserviceoutputfields = 'licensestate systemtype firmwareversion nscfwversion totalstoragespace usedstoragespace availablestoragespace'.split()
		command = "ls system full"
		namefield="objectname"
		check_generic(command=command,namefield=namefield,longserviceoutputfields=longserviceoutputfields, perfdata_fields=perfdata_fields)
		#check_systems
elif mode == 'check_controllers':
	check_controllers()
elif mode == 'check_diskgroups':
	command = "ls disk_group full"
	namefield='diskgroupname'
	longserviceoutputfields = "totaldisks levelingstate levelingprogress totalstoragespacegb usedstoragespacegb  occupancyalarmlevel".split()
	perfdata_fields="totaldisks".split()	
	check_generic(command=command,namefield=namefield,longserviceoutputfields=longserviceoutputfields, perfdata_fields=perfdata_fields)
elif mode == 'check_disks':
	check_generic(command="ls disk full",namefield="objectname")
elif mode == 'check_diskshelfs':
        check_generic(command="ls diskshelf full",namefield="diskshelfname",longserviceoutputfields=[], perfdata_fields=[])
else:
	print "* Error: Mode %s not found" % mode
	print_help()
	print "* Error: Mode %s not found" % mode
	exit(unknown)

