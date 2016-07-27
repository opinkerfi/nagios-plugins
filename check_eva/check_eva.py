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
#
# UPDATE HISTORY:
# 22 Jul 2015: Alastair Munro:
# Disk failures need a Enclosure and Bay location so we can get failed disks easily replaced. Thus
# changed objectname to this for disk checks.
# Disk checks: include the comments field for the eva, so we can easily log a ticket with HP (we
# include eva serial number and DC cabinet location in here).
# System check: included comments
# If check_system and system specified; drop system name from perf data fields and add Gb.
# Turn off perfdata for disk shelves; we don't need to graph how many fc ports it has, etc; these rarely change!
#
# 17 Mar 2016: Alastair Munro:
# No --system in the help; I wanted to add this and only discovered it by looking at the code!
# Bring back reporting number of disks checked.
# Cleaned up error reporting on failed disks.
# Added --option and then noemptybays. All disk shelves should be fully populated with disks and all 
#  shelves have the same number of disks. If a disk fails, it may get evicted and this will catch this.
#  This is part of the check_disks mode. Report warning if bays not full.
#
# 04 Apr 2016: Alastair Munro:
# notinstalled is not a valid state for fans; especially for disk shelves. Thus alert on this.
# check operationalstatedetail is not _ok. Sometimes objects report good but the detail is not _ok (eg _attention).
# for disk enclosure, advise enclosure name and state before printing number of sensors, fans, etc.
#
# 10 May 2016: Alastair Munro:
# check_controllers: powersources searching for key status rather than state. Now identifies failed/missing power supplies.
#
# 20 May 2016: Alastair Munro:
# noemptybays not working as expected; tweaked to count disks rather than highest disk.


# Some Defaults
show_perfdata = True
show_longserviceoutput = True
debugging = False


# check_eva defaults
hostname = "localhost"
username = "eva"
password = "eva1234"
mode = "check_systems"
path = ''
nagios_server = "94.142.154.10"
nagios_port = 80
nagios_myhostname = None
do_phone_home = False
escape_newlines = False
check_system = None  # By default check all systems
proxyserver = None
options = None
timeout = 0  # 0 means no timeout


# set to true, if you do not have sssu binary handy
server_side_troubleshooting = False

# No real need to change anything below here
version = "1.0.1"
ok = 0
warning = 1
critical = 2
unknown = 3
not_present = -1


state = {}
state[not_present] = "Not Present"
state[ok] = "OK"
state[warning] = "Warning"
state[critical] = "Critical"
state[unknown] = "Unknown"

longserviceoutput = "\n"
perfdata = ""

valid_modes = ("check_systems", "check_controllers", "check_diskgroups",
               "check_disks", "check_diskshelfs", "check_diskshelves")

from sys import exit
from sys import argv
from os import getenv, environ
import signal
import subprocess
import xmlrpclib
import httplib

# we need to set socket default timeout in case we are using the phone-home part
import socket
socket.setdefaulttimeout(5)


def print_help():
    print "check_eva version %s" % version
    print "This plugin checks HP EVA Array with the sssu command"
    print ""
    print "Usage: %s [OPTIONS]" % argv[0]
    print "OPTIONS:"
    print " [--host <host>]"
    print " [--username <user>]"
    print " [--password <password]"
    print " [--path </path/to/sssu>]"
    print " [--mode <mode>] "
    print " [--system <eva>] "
    print " [--test]"
    print " [--timeout <timeout>]"
    print " [--options <noemptybays>]"
    print " [--debug]"
    print " [--help]"
    print ""
    print " Valid modes are: %s" % ', '.join(valid_modes)
    print " --options are dependant on --mode:"
    print "   noemptybays (check_disks): don't ignore empty bays as a disk may have been removed. Assumes all bays are populated."
    print ""
    print "Example: %s --host commandview.example.net --username eva --password myPassword --mode check_systems" % (argv[0])


def error(errortext):
    print "* Error: %s" % errortext
    print_help()
    print "* Error: %s" % errortext
    exit(unknown)


def debug(debugtext):
    global debugging
    if debugging:
        print debugtext

# parse arguments

arguments = argv[1:]
while len(arguments) > 0:
    arg = arguments.pop(0)
    if arg == 'invalid':
        pass
    elif arg == '-H' or arg == '--host':
        hostname = arguments.pop(0)
    elif arg == '-U' or arg == '--username':
        username = arguments.pop(0)
    elif arg == '-P' or arg == '--password':
        password = arguments.pop(0)
    elif arg == '-T' or arg == '--test':
        testmode = 1
    elif arg == '--timeout':
        timeout = int(arguments.pop(0))
    elif arg == '--path':
        path = arguments.pop(0) + '/'
    elif arg == '-M' or arg == '--mode':
        mode = arguments.pop(0)
        if mode not in valid_modes:
            error("Invalid --mode %s" % arg)
    elif arg == '-d' or arg == '--debug':
        debugging = True
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
    elif arg == '--system':
        check_system = arguments.pop(0)
    elif arg == '--phone-home':
        do_phone_home = True
    elif arg == '--proxy':
        proxyserver = arguments.pop(0)
    elif arg == '--escape-newlines':
        escape_newlines = True
    elif arg == '--options':
        options = arguments.pop(0)
    elif arg == '-h' or arg == '--help':
        print_help()
        exit(ok)
    else:
        error("Invalid argument %s" % arg)


subitems = {}
subitems['fan'] = 'fans'
subitems['source'] = 'powersources'
subitems['hostport'] = 'hostports'
subitems['module'] = 'modules'
subitems['sensor'] = 'sensors'
subitems['powersupply'] = 'powersupplies'
subitems['bus'] = 'communicationbuses'
subitems['port'] = 'fibrechannelports'


def runCommand(command):
    """ runCommand: Runs command from the shell prompt. Exit Nagios style if unsuccessful """
    proc = subprocess.Popen(
        command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,)
    stdout, stderr = proc.communicate('through stdin to stdout')
    if proc.returncode > 0:
        print "Error %s: %s\n command was: '%s'" % (proc.returncode, stderr.strip(), command)
        # File not found, lets print path
        if proc.returncode == 127 or proc.returncode == 1:
            path = getenv("PATH")
            print "Current Path: %s" % path
            exit(unknown)
    else:
        return stdout


def run_sssu(system=None, command="ls system full"):
    """Runs the sssu command. This one is responsible for error checking from sssu"""
    commands = []

    continue_on_error = "set option on_error=continue"
    login = "select manager %s USERNAME=%s PASSWORD=%s" % (
        hostname, username, password)

    commands.append(continue_on_error)
    commands.append(login)
    if system is not None:
        commands.append('select SYSTEM "%s"' % system)
    commands.append(command)

    commandstring = "sssu "
    for i in commands:
        commandstring += '"%s" ' % i
    global server_side_troubleshooting
    if server_side_troubleshooting == True:
        commandstring = 'cat "debug/%s"' % command

    # print mystring
    # if command == "ls system full":
    #	output = runCommand("cat sssu.out")
    # elif command == "ls disk_groups full":
    #	output = runCommand("cat ls_disk*")
    # elif command == "ls controller full":
    #	output = runCommand("cat ls_controller")
    # else:
    #	print "What command is this?", command
    #	exit(unknown)
    output = runCommand(commandstring)
    debug(commandstring)

    output = output.split('\n')

    # Lets process the top few results from the sssu command. Make sure the
    # results make sense
    error = 0
    if output.pop(0).strip() != '':
        error = 1
    if output.pop(0).strip() != '':
        error = 2
    if output.pop(0).strip().find('SSSU for HP') != 0:
        error = 3
    if output.pop(0).strip().find('Version:') != 0:
        error = 4
    if output.pop(0).strip().find('Build:') != 0:
        error = 5
    if output.pop(0).strip().find('NoSystemSelected> ') != 0:
        error = 6
    #if output.pop(0).strip() != '': error = 1
    #if output.pop(0).strip().find('NoSystemSelected> ') != 0: error=1
    #if output.pop(0).strip() != '': error = 1
    str_buffer = ""
    for i in output:
        str_buffer = str_buffer + i + "\n"
        if i.find('Error') > -1:
            print "This is the command i was trying to execute: %s" % i
            error = 1
        if i.find('information:') > 0:
            break
    if error > 0:
        print "Error running the sssu command: " + str(error)
        print commandstring
        print str_buffer
        exit(unknown)
    objects = []
    current_object = None
    for line in output:
        if len(line) == 0:
            continue
        line = line.strip()
        tmp = line.split()
        if len(tmp) == 0:
            if current_object:
                if not current_object['master'] in objects:
                    objects.append(current_object['master'])
                current_object = None
            continue
        key = tmp[0].strip()
        if current_object and not current_object['master'] in objects:
            objects.append(current_object['master'])
        if key == 'object':
            current_object = {}
            current_object['master'] = current_object
        if key == 'controllertemperaturestatus':
            current_object = current_object['master']
        if key == 'iomodules':
            key = 'modules'
        # if key in subitems.values():
        #	object['master'][key] = []
        if key in subitems.keys():
            mastergroup = subitems[key]
            master = current_object['master']
            current_object = {}
            current_object['object_type'] = key
            current_object['master'] = master
            if not current_object['master'].has_key(mastergroup):
                current_object['master'][mastergroup] = []
            current_object['master'][mastergroup].append(current_object)

        if line.find('.:') > 0:
            # We work on first come, first serve basis, so if
            # we accidentally see same key again, we will ignore
            if not current_object.has_key(key):
                value = ' '.join(tmp[2:]).strip()
                current_object[key] = value
    # Check if we were instructed to check only one eva system
    global check_system
    if command == "ls system full" and check_system is not None:
        tmp_objects = []
        for i in objects:
            if i['objectname'] == check_system:
                tmp_objects.append(i)
        objects = tmp_objects
    return objects


def end(summary, perfdata, longserviceoutput, nagios_state):
    global show_longserviceoutput
    global show_perfdata
    global nagios_server
    global do_phone_home
    global nagios_port
    global nagios_myhostname
    global hostname
    global mode
    global escape_newlines
    global check_system

    message = "%s - %s" % (state[nagios_state], summary)
    if show_perfdata:
        message = "%s | %s" % (message, perfdata)
    if show_longserviceoutput:
        message = "%s\n%s" % (message, longserviceoutput.strip())
    if escape_newlines == True:
        lines = message.split('\n')
        message = '\\n'.join(lines)
    debug("do_phone_home = %s" % do_phone_home)
    if do_phone_home == True:
        try:
            if nagios_myhostname is None:
                if environ.has_key('HOSTNAME'):
                    nagios_myhostname = environ['HOSTNAME']
                elif environ.has_key('COMPUTERNAME'):
                    nagios_myhostname = environ['COMPUTERNAME']
                else:
                    nagios_myhostname = hostname
            try:
                phone_home(nagios_server,
                           nagios_port,
                           status=nagios_state,
                           message=message,
                           hostname=nagios_myhostname,
                           servicename=mode,
                           system=check_system
                           )
            except Exception:
                pass

        except:
            raise
    print message
    exit(nagios_state)


class ProxiedTransport(xmlrpclib.Transport):

    def set_proxy(self, proxy):
        self.proxy = proxy

    def make_connection(self, host):
        self.realhost = host
        h = httplib.HTTP(self.proxy)
        return h

    def send_request(self, connection, handler, request_body):
        connection.putrequest("POST", 'http://%s%s' % (self.realhost, handler))

    def send_host(self, connection, host):
        connection.putheader('Host', self.realhost)


def phone_home(nagios_server, nagios_port, status, message, hostname=None, servicename=None, system=None):
    """phone_home: Sends results to remote nagios server via python xml-rpc"""
    debug("phoning home: %s" % servicename)
    if system is not None:
        servicename = str(servicename) + str(system)
    uri = "http://%s:%s" % (nagios_server, nagios_port)

    global proxyserver
    if proxyserver is not None:
        p = ProxiedTransport()
        p.set_proxy(proxyserver)
        s = xmlrpclib.Server(uri, transport=p)
    else:
        s = xmlrpclib.ServerProxy(uri)
    s.nagiosupdate(hostname, servicename, status, message)
    return 0


def check_systems():
    summary = ""
    perfdata = ""
    # longserviceoutput="\n"
    nagios_state = ok
    objects = run_sssu()
    for i in objects:
        name = i['objectname']
        operationalstate = i['operationalstate']
        # Lets see if this array is working
        if operationalstate != 'good':
            nagios_state = max(nagios_state, warning)
        # Lets add to the summary
        summary += " %s=%s " % (name, operationalstate)
        # Collect the performance data
        interesting_perfdata = 'totalstoragespace|usedstoragespace|availablestoragespace'
        perfdata += get_perfdata(
            i, interesting_perfdata.split('|'), identifier="%s_" % name)
        # Collect extra info for longserviceoutput
        longoutput("%s = %s (%s)\n" %
                   (i['objectname'], i['operationalstate'], i['operationalstatedetail']))
        interesting_fields = 'licensestate|systemtype|firmwareversion|nscfwversion|totalstoragespace|usedstoragespace|availablestoragespace'
        for x in interesting_fields.split('|'):
            longoutput("- %s = %s \n" % (x, i[x]))
        longoutput("\n")
    end(summary, perfdata, longserviceoutput, nagios_state)


def get_perfdata(my_object, interesting_fields, identifier=""):
    perfdata = ""
    for i in interesting_fields:
        if i == '':
            continue
        perfdata += "'%s%s'=%s " % (identifier, i, my_object[i])
    return perfdata


def add_perfdata(text):
    global perfdata
    text = text.strip()
    perfdata += " %s " % text


def longoutput(text):
    global longserviceoutput
    longserviceoutput = longserviceoutput + text


def get_longserviceoutput(my_object, interesting_fields):
    longserviceoutput = ""
    for i in interesting_fields:
        longserviceoutput += "%s = %s \n" % (i, my_object[i])
    return longserviceoutput


def check_operationalstate(my_object, print_failed_objects=False, namefield='objectname', detailfield='operationalstatedetail', statefield='operationalstate', valid_states=None):
    if not valid_states:
        valid_states = ['good']
    if not my_object.has_key(detailfield):
        detailfield = statefield
    if not my_object.has_key(statefield):
        if print_failed_objects:
            longoutput("- Warning, %s does not have any '%s'" %
                       (my_object[namefield], statefield))
        return warning
    if my_object[statefield] not in valid_states:
        if print_failed_objects:
            longoutput("- Warning, %s=%s (%s)\n" %
                       (my_object[namefield], my_object['operationalstate'], my_object[detailfield]))
        return warning
    debug("OK, %s=%s (%s)\n" %
          (my_object[namefield], my_object['operationalstate'], my_object[detailfield]))
    return ok

# Count no. disks per shelf:
# Count no disks per shelf; highest value is number to expect per shelf.
# Report any shelves not equal to highest value.
# An oddity is that there may be a gap in the numbering!
#
def check_numdisks_pershelf(disk,systemname):
    rtn={}
    rtn['systemname']=systemname
    rtn['state']=0
    rtn['text']=None
    bay={}

    for x in disk:
        s=x['shelfnumber']
        b=int(x['diskbaynumber'])
        bay.setdefault(s, 0)
        bay[s] += 1

    maxdisk=max(bay.values())

    ns=len(bay)
    for k in sorted(bay, key=int):
        if bay[k] < maxdisk:
            if rtn['text'] is None:
                rtn['state']=1
                rtn['text']="\n%s: Failed disk/s? Some of the %d shelves have < %d disks: shelf%s=%d" % (
                    systemname, ns, maxdisk, k, bay[k])
            else:
                rtn['text']+=", shelf%s=%d" % ( k, bay[k])

    if rtn['text'] is None:
       rtn['text']="\n%s: All %d disk shelves have %d disks each." % (systemname, ns, maxdisk)
    else:
       rtn['text']+="."
    rtn['text']+="\n"
    return rtn


def check_generic(command="ls disk full", namefield="objectname", perfdata_fields=None, longserviceoutputfields=None, detailedsummary=False):
    if not perfdata_fields:
        perfdata_fields = []
    if not longserviceoutputfields:
        longserviceoutputfields = []
    global perfdata
    global options
    nagios_state = ok
    systems = run_sssu()
    objects = []
    if command == 'ls system full':
        objects = systems
        for i in systems:
            i['systemname'] = ''  # i['objectname']
    else:
        for i in systems:
            result = run_sssu(system=i['objectname'], command=command)
            if options == "noemptybays":
               shelves=check_numdisks_pershelf(result,i['objectname'])
               nagios_state = max(shelves['state'], nagios_state)
               longoutput(shelves['text'])

            for x in result:
                x['systemname'] = i['objectname']
                x['comments'] = i['comments']
                objects.append(x)


    summary = "%s objects " % len(objects)
    #print objects # debug

    usedstoragespacegb = 0
    occupancyalarmlvel = 0
    warninggb = 0
    for i in objects:
        systemname = i['systemname']
        # Some versions of commandview use "objectname" instead of namefield
        if i.has_key(namefield):
            objectname = i[namefield]
        else:
            objectname = i['objectname']

        if command == "ls disk full":
            encbay = "Enc%s_Bay%s" % (i['shelfnumber'], i['diskbaynumber'] )
        # Some versions of CV also return garbage objects, luckily it is easy
        # to find these
        if i.has_key('objecttype') and i['objecttype'] == 'typenotset':
            longoutput(
                "Object %s was skipped because objecttype == typenotset\n" % objectname)
            continue
        # Lets see if this object is working
        nagios_state = max(check_operationalstate(i), nagios_state)

        if command == "ls diskshelf full":
             longoutput("%s/%s=%s (%s)\n" %
                 (systemname, objectname, i['operationalstate'], i['operationalstatedetail']))

        # Lets add to the summary
        #if i['operationalstate'] != 'good' or detailedsummary == True:
        if i['operationalstate'] != 'good' or detailedsummary == True or not '_ok' in i['operationalstatedetail']:
            if command == "ls disk full":
                summary += " %s/%s (eva_comment=%s)=%s (%s)" % (
                    systemname, encbay, i['comments'], i['operationalstate'], i['operationalstatedetail'])
            else:
                if i['operationalstate'] == "good":
                   summary += " %s/%s=%s" % (
                       systemname, objectname, i['operationalstatedetail'])
                else:
                   summary += " %s/%s=%s (%s)" % (
                       systemname, objectname, i['operationalstate'],i['operationalstatedetail'])

            if not '_ok' in i['operationalstatedetail']:
                nagios_state = max(warning, nagios_state)

        # Lets get some perfdata
        if check_system is not None:
           identifier = "%s_" % objectname
        else:
           identifier = "%s/%s_" % (systemname, objectname)

        i['identifier'] = identifier

        for field in perfdata_fields:
            if field == '':
                continue
            if command == 'ls system full' and check_system != None:
               add_perfdata("'%s'=%sGb " %
                         (field, i.get(field, None)))
            else:
               add_perfdata("'%s%s'=%s " %
                         (identifier, field, i.get(field, None)))

        # Disk group gets a special perfdata treatment
        if command == "ls disk_group full":
            totalstoragespacegb = float(i['totalstoragespacegb'])
            usedstoragespacegb = float(i['usedstoragespacegb'])
            occupancyalarmlvel = float(i['occupancyalarmlevel'])
            warninggb = totalstoragespacegb * occupancyalarmlvel / 100
            add_perfdata(" '%sdiskusage'=%s;%s;%s " %
                         (identifier, usedstoragespacegb, warninggb, totalstoragespacegb))

        # Long Serviceoutput
        if command == "ls disk full":
                longoutput("\n%s/%s (%s)=%s (%s)\n" %
                       (systemname, objectname, encbay, i['operationalstate'], i['operationalstatedetail']))
                       #(systemname, objectname, i['operationalstate'], i['operationalstatedetail']))

        # If diskgroup has a problem because it is over allocated. Lets inform
        # about that
        if command == "ls disk_group full" and usedstoragespacegb > warninggb:
                longoutput(
                    "- %s - diskgroup usage is over %s%% threshold !\n" %
                    (state[warning], occupancyalarmlvel))
        # If a disk has a problem, lets display some extra info on it
        elif command == "ls disk full" and i['operationalstate'] != 'good':
            longoutput("Issues on this drive. Further details:\n")
            #longoutput("Warning - %s/%s=%s (%s)\n" %
                       #(systemname, encbay, i['operationalstate'], i['operationalstatedetail']))
            #fields = "objectname modelnumber firmwareversion serialnumber failurepredicted diskdrivetype shelfnumber diskbaynumber comments".split(
            fields = "modelnumber firmwareversion serialnumber failurepredicted diskdrivetype shelfnumber diskbaynumber comments".split(
            )
            for field in fields:
                longoutput("- %s = %s\n" % (field, i[field]))

        nagios_state = max(nagios_state, check_multiple_objects(i, 'sensors'))
        nagios_state = max(nagios_state, check_multiple_objects(i, 'fans'))
        nagios_state = max(
            nagios_state, check_multiple_objects(i, 'powersupplies'))
        nagios_state = max(
            nagios_state, check_multiple_objects(i, 'communicationbuses'))
        nagios_state = max(
            nagios_state, check_multiple_objects(i, 'fibrechannelports'))
        nagios_state = max(nagios_state, check_multiple_objects(i, 'modules'))
        for x in longserviceoutputfields:
            if i.has_key(x):
                longoutput("- %s = %s\n" % (x, i[x]))

    end(summary, perfdata, longserviceoutput, nagios_state)


def check_multiple_objects(my_object, name):
    item_status = not_present
    if my_object.has_key(name):
        item_status = not_present
        valid_states = ['good']
        namefield = "name"
        detailfield = 'operationalstatedetail'

        #if name == 'fans' or name == 'sensors':
        if name == 'sensors':
            valid_states = [
                'good', 'notavailable', 'unsupported', 'notinstalled']
        elif name == 'fans':
            valid_states = [
                'good', 'notavailable', 'unsupported']
        elif name == 'fibrechannelports':
            valid_states.append('notinstalled')
        num_items = len(my_object[name])
        for item in my_object[name]:
            stat = check_operationalstate(
                item, print_failed_objects=True, namefield=namefield, valid_states=valid_states, detailfield=detailfield)
            item_status = max(stat, item_status)
        longoutput('- %s on %s (%s detected)\n' %
                   (state[item_status], name, num_items))
        add_perfdata(" '%s%s'=%s" %
                     (my_object['identifier'], name, num_items))
    return item_status


def check_controllers():
    perfdata = ""
    # longserviceoutput="\n"
    nagios_state = ok
    systems = run_sssu()
    controllers = []
    for i in systems:
        result = run_sssu(system=i['objectname'], command="ls controller full")
        for controller in result:
            controller['systemname'] = i['objectname']
            controllers.append(controller)
    summary = "%s objects " % len(controllers)
    for i in controllers:
        systemname = i['systemname']
        if i.has_key('controllername'):
            controllername = i['controllername']
        else:
            controllername = i['objectname']
        # Lets see if this controller is working
        nagios_state = max(check_operationalstate(i), nagios_state)

        # Lets add to the summary
        if not i.has_key('operationalstate'):
            summary += " %s does not have any operationalstate " % controllername
            nagios_state = max(unknown, nagios_state)
            continue
        elif i['operationalstate'] != 'good':
            summary += " %s/%s=%s " % (
                systemname, controllername, i['operationalstate'])

        # Lets get some perfdata
        interesting_fields = "controllermainmemory"
        identifier = "%s/%s_" % (systemname, controllername)
        perfdata += get_perfdata(
            i, interesting_fields.split('|'), identifier=identifier)

        # Long Serviceoutput
        #longserviceoutput = longserviceoutput + get_longserviceoutput(i, interesting_fields.split('|') )
        #longserviceoutput = longserviceoutput + "\n%s/%s\n"%(systemname,controllername)
        longoutput("\n%s/%s = %s (%s)\n" %
                   (systemname, controllername, i['operationalstate'], i['operationalstatedetail']))
        longoutput("- firmwareversion = %s \n" % (i['firmwareversion']))
        longoutput("- serialnumber = %s \n" % (i['serialnumber']))

        controllertemperaturestatus = not_present
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
            hostportstate = max(hostportstate, ok)
            if hostport['operationalstate'] != 'good':
                hostportstate = max(warning, hostportstate)
                message = "Hostport %s state = %s\n" % (
                    hostport['portname'], hostport['operationalstate'])
                longoutput(message)
        if i.has_key('fans'):
            for fan in i['fans']:
                fanstate = max(fanstate, ok)
                #long(" %s = %s\n" % (fan['fanname'], fan['status']))
                if fan.has_key('status'):
                    status = fan['status']
                elif fan.has_key('installstatus'):
                    status = fan['installstatus']
                if status != 'normal' and status != 'yes':
                    fanstate = max(warning, fanstate)
                    longoutput("Fan %s status = %s\n" %
                               (fan['fanname'], status))
        if i.has_key('powersources'):
            for source in i['powersources']:
                source_state = max(source_state, ok)
                #if not source.has_key('status'): # Should be state not status
                if not source.has_key('state'):
                    continue
                if source['state'] != 'good':
                    source_state = max(warning, source_state)
                    longoutput("Powersource %s state = %s\n" %
                               (source['type'], source['state']))
        if i.has_key('modules'):
            for module in i['modules']:
                module_state = max(module_state, ok)
                if module['operationalstate'] not in ('good', 'not_present'):
                    module_state = max(warning, module_state)
                    longoutput("Battery Module %s status = %s\n" %
                               (module['name'], module['operationalstate']))

        for i in (fanstate, hostportstate, sensorstate, source_state, module_state, cache_state, controllertemperaturestatus):
            nagios_state = max(nagios_state, i)

        longoutput("- %s on fans\n" % (state[fanstate]))
        longoutput("- %s on cachememory\n" % (state[cache_state]))
        longoutput("- %s on temperature\n" %
                   (state[controllertemperaturestatus]))
        longoutput("- %s on hostports\n" % (state[hostportstate]))
        longoutput("- %s on sensors\n" % (state[sensorstate]))
        longoutput("- %s on powersupplies\n" % (state[source_state]))
        longoutput("- %s on batterymodules\n" % (state[module_state]))

        longoutput('\n')
    end(summary, perfdata, longserviceoutput, nagios_state)


def set_path():
    global path
    current_path = getenv('PATH')
    if path == '':
        if current_path.find('C:\\') > -1:  # We are on this platform
            path = ";C:\\Program Files\\Hewlett-Packard\\Sanworks\\Element Manager for StorageWorks HSV"
        else:
            path = ":/usr/local/bin"
    current_path = "%s%s" % (current_path, path)
    environ['PATH'] = current_path
set_path()


# Create an alarm so that plugin can exit properly if timeout occurs
exit_with_timeout = lambda x, y: error("Timeout of %s seconds exceeded" % timeout)
signal.signal(signal.SIGALRM, exit_with_timeout)
signal.alarm(timeout)

if mode == 'check_systems':
    perfdata_fields = 'totalstoragespace usedstoragespace availablestoragespace'.split(
    )
    longserviceoutputfields = 'comments licensestate systemtype firmwareversion nscfwversion totalstoragespace usedstoragespace availablestoragespace'.split(
    )
    command = "ls system full"
    namefield = "objectname"
    check_generic(command=command, namefield=namefield,
                  longserviceoutputfields=longserviceoutputfields, perfdata_fields=perfdata_fields)
elif mode == 'check_controllers':
    check_controllers()
elif mode == 'check_diskgroups':
    command = "ls disk_group full"
    namefield = 'diskgroupname'
    longserviceoutputfields = "totaldisks levelingstate levelingprogress totalstoragespacegb usedstoragespacegb  occupancyalarmlevel".split(
    )
    perfdata_fields = "totaldisks".split()
    check_generic(command=command, namefield=namefield,
                  longserviceoutputfields=longserviceoutputfields, perfdata_fields=perfdata_fields)
elif mode == 'check_disks':
    check_generic(command="ls disk full", namefield="objectname")
elif mode == 'check_diskshelfs' or mode == 'check_diskshelves':
    show_perfdata = False # Ideally should fixed the code; but this does the trick!
    check_generic(command="ls diskshelf full", namefield="diskshelfname",
                  longserviceoutputfields=[], perfdata_fields=[])
else:
    print "* Error: Mode %s not found" % mode
    print_help()
    print "* Error: Mode %s not found" % mode
    exit(unknown)
