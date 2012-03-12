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
CHECK_COMMAND="group_tool ls 0 default" 	# Default command to check selinux status
ok=0
warning=1
critical=2
unknown=3

print_help() {
      echo "check_rhcs_cman version $VERSION"
      echo "This plugin checks cman groups"
      echo ""
      echo "Usage: $0 [-H <host>] <-l LEVEL> <--group GROUP>"
      echo ""
      echo "Examples:"
      echo "# check_rhcs_fencing.sh --level 0 --group default"
      echo "# check_rhcs_fencing.sh --level 1 --group rgmanager"
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
    --group)
      GROUP=$2
      shift 2
    ;;
    --level)
      LEVEL=$2
      shift 2
    ;;

    *)
      print_help ;
      exit $UNKNOWN
      ;;
  esac
done

if [ -z $GROUP ]; then
	echo "ERROR - --group not specified"
	print_help ;
	exit $UNKNOWN
fi

if [ -z $LEVEL ]; then
	echo "ERROR - --level not specified"
	print_help ;
	exit $UNKNOWN
fi



# We we are not checking localhost, lets get remote uptime via NRPE
if [ "$HOSTN" != "localhost" ]; then
	export PATH=$PATH:/usr/lib/nagios/plugins:/usr/lib64/nagios/plugins:/nagios/usr/lib/nagios/plugins
	CHECK_COMMAND="check_nrpe -H $HOSTN -c check_cman_group -a $LEVEL $GROUP"
fi

CHECK_COMMAND="group_tool ls $LEVEL $GROUP"

# group_tool ls
# type             level name       id       state
# fence            0     default    00020001 none
# [1]
# dlm              1     rgmanager  00030001 none
#[1 2]

# Get the uptime, raise error if we are unsuccessful
OUTPUT=`$CHECK_COMMAND 2>&1`
RESULT=$?
SUMMARY=""


# group_tool should only return status 0 or 1
# if higher, then something unexpected occured
if [ $RESULT -ge 2 ]; then
	echo "group_tool error: could not run command $CHECK_COMMAND"
	echo "output:"
	echo "$OUTPUT"
	exit $unknown
fi

set -- $OUTPUT
type=$6
level=$7
name=$8
id=$9
state=${10}
# Check if group_tool command ran successfully
if [ $RESULT -ne 0 ]; then
	echo "group_tool error: group $GROUP level $LEVEL not found."
	echo "output:"
	echo "$OUTPUT"
	exit $critical
else
	echo $OUTPUT | grep -qw "none" 
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		echo "group_tool error: group is in abnormal state. name=$name type=$type level=$level state=$state"
		echo "output:"
		echo "$OUTPUT"
		exit $critical
	else
		echo "group_tool: group ok and in state 'none'. name=$name type=$type level=$level state=$state"
		echo "output:"
		echo "$OUTPUT"
		exit $ok
	fi
fi
