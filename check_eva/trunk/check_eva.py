#!/usr/bin/python


# First some defaults
hostname="evahost"
username="eva"
password="eval1234"
mode="check_systems"
debug = False
path=''

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

valid_modes = ( "check_systems", "check_controllers", "check_diskgroups","check_disks", "check_diskshelfs")

from sys import exit
from sys import argv
import subprocess


def print_help():
	print "check_eva version %s" % version
	print "This plugin of HP EVA Array with the sssu command"
	print ""
	print "Usage: %s [OPTIONS]" % argv[0]
	print "OPTIONS:"
	print  " [--host <host>]"
	print  " [--username <user>]"
	print  " [--password <password]"
	print  " [--mode <mode>] "
	print  " [--test]"
	print  " [--help]"
	print  ""
	print  " Valid modes are: %s" % ', '.join(valid_modes)


def error(errortext):
	print "* Error: %s" % errortext
	print_help()
	print "* Error: %s" % errortext
	exit(unknown)

def debug( debugtext ):
	debug = False
	if debug:
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


'''runCommand: Runs command from the shell prompt. Exit Nagios style if unsuccessful'''
def runCommand(command):
  proc = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE,stderr=subprocess.PIPE,)
  stdout, stderr = proc.communicate('through stdin to stdout')
  if proc.returncode > 0:
    print "Errorcode %s on command '%s' (%s)" % (proc.returncode,command, stderr.strip())
    #print stderr, stdout
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
	if path != '': commandstring = path + commandstring
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
	if output.pop(0) != '': error = 1
	if output.pop(0) != '': error = 1
	if output.pop(0) != 'SSSU for HP StorageWorks Command View EVA': error = 1
	if output.pop(0).find('Version:') != 0: error=1
	if output.pop(0).find('Build:') != 0: error=1
	if output.pop(0).find('NoSystemSelected> ') != 0: error=1
	if output.pop(0) != '': error = 1
	if output.pop(0).find('NoSystemSelected> ') != 0: error=1
	if output.pop(0) != '': error = 1
	buffer = ""
	for i in output:
		buffer = buffer + i + "\n"
		if i.find('error') > -1:
			print "Error running sssu command: %s" % i
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
		if key in subitems.values():
			object['master'][key] = []
		if key in subitems.keys():
			mastergroup = subitems[key]
			master = object['master']
			object = {}
			object['object_type'] = key
			object['master'] = master
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
	print "%s - %s | %s" % (state[nagios_state], summary,perfdata)
	print longserviceoutput
	exit(nagios_state)

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


def long(text):
	global longserviceoutput
	longserviceoutput = longserviceoutput + text
def get_longserviceoutput(object, interesting_fields):
	longserviceoutput = ""
	for i in interesting_fields:
		longserviceoutput = longserviceoutput + "%s = %s \n" %(i, object[i])
	return longserviceoutput

def check_operationalstate(object, print_failed_objects=False,namefield='objectname',detailfield='operationalstate',valid_states=['good']):
	if object['operationalstate'] not in valid_states:
		if print_failed_objects:
			long("Warning, %s=%s (%s)\n" % ( object[namefield], object['operationalstate'], object[detailfield] ))
		return warning
	debug( "OK, %s=%s (%s)\n" % ( object[namefield], object['operationalstate'], object[detailfield] ) )
	return ok


def check_diskgroups():
	summary=""
	perfdata=""
	nagios_state = ok
	systems = run_sssu()
	objects = []
	for i in systems:
		result = run_sssu(system=i['objectname'], command="ls disk_group full")
		for x in result:
			x['systemname'] = i['objectname']
			objects.append( x )
	for i in objects:
		systemname = i['systemname']
		objectname = i['diskgroupname']
		# Lets see if this object is working
		nagios_state = max( check_operationalstate(i), nagios_state )

		# Lets add to the summary
		summary = summary + " %s/%s=%s " %(systemname,objectname, i['operationalstate'])
		
		# Lets get some perfdata
		interesting_fields = "totaldisks|totalstoragespacegb|usedstoragespacegb|occupancyalarmlevel"
		identifier = "%s/%s_" % (systemname,objectname)
		perfdata = perfdata + get_perfdata(i, interesting_fields.split('|'), identifier=identifier)

		# Long Serviceoutput
		interesting_fields = "totaldisks levelingstate levelingprogress totalstoragespacegb usedstoragespacegb  occupancyalarmlevel"
		long( "\n%s/%s = %s (%s)\n"%(systemname,objectname,i['operationalstate'], i['operationalstatedetail']) )
		for x in interesting_fields.split():
			long( "- %s = %s\n" % (x, i[x]))

	end(summary,perfdata,longserviceoutput,nagios_state)
		

def check_generic(command="ls disk full",namefield="objectname", perfdata_fields=[], longserviceoutputfields=[], detailedsummary=False):
        summary=""
        perfdata=""
        nagios_state = ok
        systems = run_sssu()
        objects = []
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
		if command == "ls disk_group full":
			totalstoragespacegb=i['totalstoragespacegb']
			usedstoragespacegb=i['usedstoragespacegb']
			warninggb= float(totalstoragespacegb) * float( i['occupancyalarmlevel'] ) / 100
			perfdata = perfdata + " '%sdiskusage'=%s;%s;%s "% (identifier, usedstoragespacegb,warninggb,totalstoragespacegb)

		for field in perfdata_fields:
			if field == '': continue
			perfdata = perfdata + "'%s%s'=%s " % (identifier, field, i[field])


                # Long Serviceoutput
                #interesting_fields = "totaldisks levelingstate levelingprogress totalstoragespacegb usedstoragespacegb  occupancyalarmlevel"
		if command == "ls disk full":
			pass
		else:
			long( "\n%s/%s = %s (%s)\n"%(systemname,objectname,i['operationalstate'], i['operationalstatedetail']) )
		if command == "ls disk_group full" and usedstoragespacegb > warninggb:
				long("- %s - diskgroup usage is over threshold!\n" % state[warning])
		elif command == "ls disk full" and i['operationalstate'] != 'good':
			long( "Warning - %s=%s (%s)\n" % (i['diskname'], i['operationalstate'], i['operationalstatedetail'] ))
			fields="modelnumber firmwareversion serialnumber failurepredicted  diskdrivetype".split()
			for field in fields:
				long( "- %s = %s\n" % (field, i[field]) )
		if i.has_key('powersupplies'): # disk_shelf has this
			powersupply_status = not_present
			for powersupply in i['powersupplies']:
				powersupply_status = max( check_operationalstate( powersupply, print_failed_objects=True, namefield='name', detailfield='name'), powersupply_status )
			nagios_state = max(nagios_state, powersupply_status)
			long('- %s on powersupplies\n'% state[powersupply_status])
		if i.has_key('sensors'): # disk_shelf has this
			sensor_status = not_present
			for sensor in i['sensors']:
				stat = check_operationalstate( sensor,print_failed_objects=True, namefield='name', valid_states=['good','notavailable','unsupported'])
				sensor_status = max( stat, sensor_status )
			nagios_state = max(nagios_state, sensor_status)
			long('- %s on sensors\n'% state[sensor_status])
				

                for x in longserviceoutputfields:
                        long( "- %s = %s\n" % (x, i[x]))

        end(summary,perfdata,longserviceoutput,nagios_state)



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
		long( "-firmwareversion = %s \n" %(i['firmwareversion']))
		long( "-serialnumber = %s \n" %(i['serialnumber']))


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
		for fan in i['fans']:
			fanstate = max(fanstate,ok)
			#long(" %s = %s\n" % (fan['fanname'], fan['status']))
			if fan.has_key('status'): status = fan['status']
			elif fan.has_key('installstatus'): status = fan['installstatus']
			if status != 'normal' and status != 'yes':
				fanstate = max(warning,fanstate)
				long("Fan %s status = %s\n" % (fan['fanname'],status))
		for source in i['powersources']:
			source_state = max(source_state,ok)
			if not source.has_key('status'): continue
			if source['state'] != 'good':
				source_state = max(warning,source_state)
				long("Powersource %s status = %s\n" % (source['type'],source['state']))
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

if mode == 'check_systems':
	check_systems()
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

