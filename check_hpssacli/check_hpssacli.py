#!/usr/bin/python
#
# Copyright 2019, Gardar Thorsteinsson <gardar@ok.is>
#
# check_hpssacli.py is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# check_hpssacli.py is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# About this script
#
# This script will check the status of Smart Array Raid Controller
# You need the hpssacli binary in path (/usr/sbin/hpssacli is a good place)
# hpssacli comes with the Proliant Support Pack (PSP) from HP

debugging = False

# No real need to change anything below here
version = "1.1"
ok = 0
warning = 1
critical = 2
unknown = 3
not_present = -1
nagios_status = -1

state = {}
state[not_present] = "Not Present"
state[ok] = "OK"
state[warning] = "Warning"
state[critical] = "Critical"
state[unknown] = "Unknown"


longserviceoutput = "\n"
perfdata = ""
summary = ""
sudo = False


from sys import exit
from sys import argv
from os import getenv, putenv, environ
import subprocess


def print_help():
    print "check_hpssacli version %s" % version
    print "This plugin checks HP Array with the hpssacli command"
    print ""
    print "Usage: %s " % argv[0]
    print "Usage: %s [--help]" % argv[0]
    print "Usage: %s [--version]" % argv[0]
    print "Usage: %s [--path </path/to/hpssacli>]" % argv[0]
    print "Usage: %s [--no-perfdata]" % argv[0]
    print "Usage: %s [--no-longoutput]" % argv[0]
    print  ""


def error(errortext):
    print "* Error: %s" % errortext
    print_help()
    print "* Error: %s" % errortext
    exit(unknown)


def debug(debugtext):
    global debugging
    if debugging:
        print  debugtext


def runCommand(command):
    """ Run command from the shell prompt. Exit Nagios style if unsuccessful"""
    proc = subprocess.Popen(command,
                            shell=True,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            )
    stdout, stderr = proc.communicate('through stdin to stdout')
    if proc.returncode > 0:
        print "Error %s: %s\n command was: '%s'"\
              % (proc.returncode, stderr.strip(), command)
    debug("results: %s" % (stdout.strip()))
    if proc.returncode == 127:  # File not found, lets print path
        path = getenv("PATH")
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
    print "%s - %s | %s" % (state[nagios_status], summary, perfdata)
    print longserviceoutput
    if nagios_status < 0:
        nagios_status = unknown
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
    if current_path.find('C:\\') > -1:  # We are on this platform
        if path == '':
            path = ";C:\Program Files\hp\hpssacli\Bin"
            path = path + ";C:\Program Files (x86)\hp\hpssacli\Bin"
            path = path + ";C:\Program Files\Smart Storage Administrator\ssacli\bin"
        else:
            path = ';' + path
    else:  # Unix/Linux, etc
        if path == '':
            path = ":/usr/sbin"
        else:
            path = ':' + path
    current_path = "%s%s" % (current_path, path)
    environ['PATH'] = current_path


def run_hpssacli(run_type='controllers', controller=None):
    if run_type == 'controllers':
        command = "hpssacli  controller all show detail"
    elif run_type in ('logicaldisks', 'physicaldisks'):
        if 'Slot' not in controller:
            add_summary("Controller not found")
            end()
        identifier = 'slot=%s' % (controller['Slot'])
        command = "hpssacli  controller %s %s all show detail"
        if run_type == 'logicaldisks':
            subcommand = 'ld'
        elif run_type == 'physicaldisks':
            subcommand = 'pd'
        else:
            end()
            return
        command = command % (identifier, subcommand)
    debug(command)
    if sudo:
        command = "sudo " + command
    output = runCommand(command)
    # Some basic error checking
    error_strings = ['Permission denied']
    error_strings.append('Error: You need to have administrator rights to continue.')
    for error in error_strings:
        if output.find(error) > -1 and output.find("sudo") != 0:
            command = "sudo " + command
            print command
            output = runCommand(command)
    output = output.split('\n')
    objects = []
    my_object = None
    for i in output:
        if len(i) == 0:
            continue
        if i.strip() == '':
            continue
        if i.startswith('Note:'):
            continue
        if run_type == 'controllers' and i[0] != ' ':   # space on first line
            if my_object and not my_object in objects:
                objects.append(my_object)
            my_object = {}
            my_object['name'] = i
        elif run_type == 'logicaldisks' and i.find('Logical Drive:') > 0:
            if my_object and not my_object in objects:
                objects.append(my_object)
            my_object = {}
            my_object['name'] = i.strip()
        elif run_type == 'physicaldisks' and i.find('physicaldrive') > 0:
            if my_object and not my_object in objects:
                objects.append(my_object)
            my_object = {}
            my_object['name'] = i.strip()
        else:
            i = i.strip()
            if i.find(':') < 1:
                continue
            i = i.split(':')
            if i[0] == '':
                continue  # skip empty lines
            if len(i) == 1:
                continue
            key = i[0].strip()
            value = ' '.join(i[1:]).strip()
            my_object[key] = value
    if my_object and not my_object in objects:
        objects.append(my_object)
    return objects


controllers = []


def check_controllers():
    global controllers
    status = -1
    controllers = run_hpssacli()
    if len(controllers) == 0:
        add_summary("No Disk Controllers Found. Exiting...")
        global nagios_state
        nagios_state = unknown
        end()
    add_summary("Found %s controllers" % (len(controllers)))
    for i in controllers:
        controller_status = check(i, 'Controller Status', 'OK')
        status = max(status, controller_status)

        cache_status = check(i, 'Cache Status')
        status = max(status, cache_status)

        controller_serial = 'n/a'
        cache_serial = 'n/a'
        if 'Serial Number' in i:
            controller_serial = i['Serial Number']
        if 'Cache Serial Number' in i:
            cache_serial = i['Cache Serial Number']
        add_long("%s" % (i['name']))
        add_long("- Controller Status: %s (sn: %s)"
                 % (state[controller_status], controller_serial))
        add_long("- Cache Status: %s (sn: %s)"
                  % (state[cache_status], cache_serial))

        if controller_status > ok or cache_status > ok:
            add_summary(";%s on %s;" % (state[controller_status], i['name']))

    add_summary(', ')
    return status


def check_logicaldisks():
    global controllers
    if len(controllers) < 1:
        controllers = run_hpssacli()
    logicaldisks = []
    for controller in controllers:
        for ld in run_hpssacli(run_type='logicaldisks',
                                controller=controller):
            logicaldisks.append(ld)
    status = -1
    add_long("\nChecking logical Disks:")
    add_summary("%s logicaldisks" % (len(logicaldisks)))
    for i in logicaldisks:
        ld_status = check(i, 'Status')
        status = max(status, ld_status)

        if i.get('Status') == 'Failed':
            status = max(status, critical)

        mount_point = i['Mount Points']
        add_long("- %s (%s) = %s" % (i['name'], mount_point, state[ld_status]))
    add_summary(". ")


def check_physicaldisks():
    global controllers
    disktype = 'physicaldisks'
    if len(controllers) < 1:
        controllers = run_hpssacli()
    disks = []
    for controller in controllers:
        for disk in run_hpssacli(run_type=disktype, controller=controller):
            disks.append(disk)
    status = -1
    add_long("\nChecking Physical Disks:")
    add_summary("%s %s" % (len(disks), disktype))
    for i in disks:
        disk_status = check(i, 'Status')
        status = max(status, disk_status)

        size = i['Size']
        firmware = i['Firmware Revision']
        interface = i['Interface Type']
        serial = i['Serial Number']
        model = i['Model']
        add_long("- %s, %s, %s = %s" %
                 (i['name'], interface, size, state[disk_status])
        )
        if disk_status > ok:
            error_str = "-- Replace drive, firmware=%s, model=%s, serial=%s"
            add_long(error_str % (firmware, model, serial))
    if status > ok:
        add_summary("(errors)")
        add_summary(". ")


def check(my_object, field, valid_states=None):
    if valid_states is None:
        valid_states = ['OK']
    state = -1
    global nagios_status
    if field in my_object:
        if my_object[field] in valid_states:
            state = ok
        else:
            state = warning
    nagios_status = max(nagios_status, state)
    return state


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
        elif arg == '--sudo':
            global sudo
            sudo = True
        else:
            print_help()
            exit(unknown)


def main():
    parse_arguments()
    set_path('')
    check_controllers()
    check_logicaldisks()
    check_physicaldisks()
    end()


if __name__ == '__main__':
    main()
