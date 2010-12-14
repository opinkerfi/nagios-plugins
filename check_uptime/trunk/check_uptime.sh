#!/bin/bash
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
# Checks uptime of a specified host, using NRPE is host is remote

HOSTN="localhost" 	# By default check localhost
CHECK_COMMAND="uptime" 	# Default command to check uptime

print_help() {
      echo "$0 version $VERSION"
      echo "This plugin checks uptime of local or remote host"
      echo ""
      echo "Usage: $0 [-H <host>]"
      echo ""
      echo "Example: Check uptime of a remote host"
      echo "# $0 -H remotehost -s Enforcing"
}

# Parse arguments
while [ $# -gt 0 ]
do
  case $1
  in
    -H)
      HOSTN=$2
      shift 2
    ;;

    *)
      print_help ;
      exit $UNKNOWN
      ;;
  esac
done




# We we are not checking localhost, lets get remote uptime via NRPE
if [ "$HOSTN" != "localhost" ]; then
	export PATH=$PATH:/usr/lib/nagios/plugins:/usr/lib64/nagios/plugins:/nagios/usr/lib/nagios/plugins
	CHECK_COMMAND="check_nrpe -H $HOSTN -c get_uptime"
fi





# Get the uptime, raise error if we are unsuccessful
OUTPUT=`$CHECK_COMMAND`
RESULT=$?

if [ $RESULT -gt 0 ]; then
	echo "Error - Could not run command $CHECK_COMMAND"
	echo "Error was: $OUTPUT"
	exit 3
fi

# Parse the output from uptime command
set -- $OUTPUT
if [ $4 == 'min(s),' ]; then
	echo "Warning, $HOSTN uptime is $OUTPUT"
	exit 1
elif [ `echo $3 | grep -c :` -gt 0 ]; then
	echo "Ok, ${HOSTN} uptime is $OUTPUT"
	exit 0
else
	echo "Ok, ${HOSTN} uptime is $OUTPUT"
	exit 0
fi
	

