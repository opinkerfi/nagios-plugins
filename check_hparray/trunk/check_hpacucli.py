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
# This script will check the status of all EVA arrays via the sssu binary.
# You will need the sssu binary in path (/usr/bin/sssu is a good place)
# If you do not have sssu, check your commandview CD, it should have both
# binaries for Windows and Linux

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
    #if proc.returncode == 127: # File not found, lets print path
    path=getenv("PATH")
    print "Current Path: %s" % (path)
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
		path = ";C:\Program Files\Hewlett-Packard\Sanworks\Element Manager for StorageWorks HSV"
		path = path + ";C:\Program Files (x86)\Compaq\Hpacucli\Bin"
		path = path + ";C:\Program Files\Compaq\Hpacucli\Bin"
	else:
		path = ":/usr/local/bin"
	current_path = "%s%s" % (current_path,path)
	environ['PATH'] = current_path




def run_hpacucli(type='controllers', controller=None):
	if type=='controllers':
		command="hpacucli  controller all show detail"
	elif type=='logicaldisks' or type=='physicaldisks':
		if controller.has_key('Slot'):
			identifier = 'slot=%s' % (controller['Slot'] )
		if type=='logicaldisks':
			command = "hpacucli  controller %s ld all show detail" % (identifier)
		if type=='physicaldisks':
			command = "hpacucli  controller %s pd all show detail" % (identifier)
	
	#command="hpacucli  controller slot=1 ld all show detail"
	#command="hpacucli  controller slot=1 ld all show detail"
	debug ( command ) 
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
	controllers = run_hpacucli()
	status = -1
	add_summary( "%s controllers found" % ( len(controllers) ) )
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

	add_summary('. ')	
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
        add_summary( "%s logicaldisks found" % ( len(logicaldisks) ) )
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
        add_summary( "%s %s found" % ( len(disks), disktype ) )
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

def main():
	pass


if __name__ == '__main__':
	main()
	set_path('')
	check_controllers()
	check_logicaldisks()
	check_physicaldisks()
	end()	
