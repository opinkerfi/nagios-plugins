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

HOSTN="localhost" 		# By default check localhost
CHECK_COMMAND="test ! -p /tmp/fence_manual.fifo" 	# Default command to check selinux status

print_help() {
      echo "check_rhcs_fencing version $VERSION"
      echo "This plugin checks if there is Manual ACK is required for RHCS fencing"
      echo ""
      echo "Usage: $0 [-H <host>]"
      echo ""
      echo "Example: Check if fencing is required on localhost"
      echo "# check_rhcs_fencing.sh"
}

#if [ $# -eq 0 ]; then
#     print_help ;
#     exit $UNKNOWN
#fi


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
	CHECK_COMMAND="check_nrpe -H $HOSTN -c check_rhcs_fencing"
fi


# Get the uptime, raise error if we are unsuccessful
OUTPUT=`$CHECK_COMMAND`
RESULT=$?

if [ $RESULT -eq 2 ]; then
	echo "Error, could not run command $CHECK_COMMAND"
	echo "output:"
	echo "$OUTPUT"
	exit 3
fi

if [ $RESULT -gt 0 ]; then
	echo "Warning, /tmp/fence_manual.fifo exists on host $HOSTN. Manual fencing is required"
	exit 1
else
	echo "Ok, No fencing required on host $HOSTN"
	exit 0
fi
