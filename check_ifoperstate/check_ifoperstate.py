#!/usr/bin/python
#
# Copyright 2013, Tomas Edwardsson
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

# Enumerates interfaces and their operstate (up/down/unknown).

__author__ = 'Tomas Edwardsson <tommi@tommi.org>'

from subprocess import PIPE, Popen
import os
import sys
from pynag.Plugins import PluginHelper, ok, critical, unknown

helper = PluginHelper()

helper.parser.add_option('-I', "--interface", help="Interface (eth0/bond/em/..) multiple supported with -I ... -I ...",
                         dest="interfaces", action="append")
helper.parser.add_option('-H', "--hostname", help="Check interface on remote host", dest="host_name")
helper.parser.add_option('-l', "--list-interfaces", help="List interfaces", dest="list_interfaces", action="store_true")

helper.parse_arguments()

local_env = os.environ
local_env["PATH"] += ":%s" % (":".join([
    "/usr/lib/nagios/plugins",
    "/usr/lib64/nagios/plugins",
    "/usr/local/libexec",
    "/usr/libexec",
    "/usr/local/nagios/libexec"]))

if helper.options.host_name:
    command = ("check_nrpe -H %s -c get_ifoperstate" % helper.options.host_name).split()
else:
    command = ["get_ifoperstate.sh"]


# List the interfaces and exit
def get_interfaces():
    interfaces = []
    try:
        cmd = Popen(command, stdout=PIPE, shell=False)
        for line in cmd.stdout.readlines():
            interface, status = line.strip().split(":")
            interfaces.append((interface, status))

    except Exception, e:
        helper.add_summary("Unable to get interfaces \"%s\": %s" % (" ".join(command), e))
        helper.status(unknown)
        helper.exit()
    return interfaces

interface_state = get_interfaces()

if helper.options.list_interfaces:
    for interface in interface_state:
        print "%-20s %s" % (interface[0], interface[1])
    sys.exit(0)


for interface in interface_state:
    if not helper.options.interfaces or interface[0] in helper.options.interfaces:
        if interface[1] == "unknown":
            helper.add_status(unknown)
        elif interface[1] == "up":
            helper.add_status(ok)
        else:
            helper.add_status(critical)
        helper.add_long_output("%s operstate is %s" % (interface[0], interface[1]))

helper.check_all_metrics()
helper.exit()
