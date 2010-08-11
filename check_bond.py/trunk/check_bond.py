#!/usr/bin/python

# Copyright 2010, Tomas Edwardsson 
#
# check_bond.py is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# check_bond.py is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import pprint
import re
import sys
import getopt



def readbond( interface ):
	intfile = "/proc/net/bonding/%s" % interface

	# Read interface info
	try:
		bondfh = open (intfile, 'r')
	except IOError, (errno, strerror):
		print "Unable to open bond %s: %s" %  (intfile, strerror)
		sys.exit(3)
	except:
		print "Unexpected error:", sys.exc_info()[0]
		sys.exit(3)

	# Initialize bond data
	bond = {}
	bond['slaves'] = []
	
	# Which interface are we working with
	current_int = ''

	# Loop throught the file contents
	for line in bondfh.readlines():
		# Remove newlines and split on colon, ignore other
		try:
			k, v = line.replace('\n', '').split(': ', 1)
		except:
			pass

		# Remove leading whitespaces
		k = re.sub('^\s*', '', k)
		# Bonding mode for the channel
		if k == "Bonding Mode":
			bond['bonding_mode'] = v
		# Record current slave interface
		elif k == "Slave Interface":
			current_int = v
		# Slave interface mii status
		elif current_int and k == "MII Status":
			bond['slaves'].append( { 'int' : current_int, 'mii_status' : v })
		# Bond mii status
		elif k == "MII Status":
			bond['mii_status'] = v
			
	return bond

def usage():
    print "Usage: %s -i bond0" % sys.argv[0]

def main(argv):
    # Set variables
    interface = ''
    outstring = ''
    retval = 0

    # Nagios return code states
    states = { 0 : 'OK', 1 : 'Warning', 2 : 'Critical', 3 : 'Unknown' }

    # Try to read the arguments
    try:                                
        opts, args = getopt.getopt(argv, "hi:", ["help", "interface="])
    except getopt.GetoptError:
        usage()
        sys.exit(3)


    for opt, arg in opts:
	if opt in ("-h", "--help"):
	    usage()
	    sys.exit(3)
	elif opt in ("-i", "--interface"):
	    interface = arg

    if (interface == ""):
	usage()
	sys.exit(3)

    bond = readbond(interface)

    # The whole bond is down
    if bond['mii_status'] != 'up':
	print "Critical: bonding device %s %s" % (interface, bond['mii_status'])
	sys.exit(2)

	# Some interface in the bond is down
	for slave in bond['slaves']:
		if slave['mii_status'] != 'up':
			outstring = "%s%s down " % (outstring, slave['int'])
			if retval < 1:
				retval = 1

	if retval:
		print "%s: %s%s %s" % (states[retval], outstring, "in bonding device", interface)
		sys.exit(retval)

	print "OK: bonding device %s up and running" % interface
	sys.exit(0)


if __name__ == "__main__":
    main(sys.argv[1:])
