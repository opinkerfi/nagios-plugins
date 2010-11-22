#!/bin/sh
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
# This script will check for established TCP connection via SNMP




LOCAL_HOST=$1
LOCAL_PORT=$2
COMMUNITY=$3
REMOTE_HOST=$4
REMOTE_PORT=$5

if [ -z $REMOTE_HOST ]; then
	echo "Usage: $0 <local_host> <local_port> <snmp_community> <remote_host>"
	exit 3
fi

OUTPUT=`/usr/bin/snmpwalk -v 2c -c $COMMUNITY $LOCAL_HOST TCP-MIB::tcpConnState.$LOCAL_HOST.$LOCAL_PORT.$REMOTE_HOST | grep -q established`
RESULT=$?

if [ $RESULT -gt 0 ]; then
	echo "TCP Connection from $REMOTE_HOST to $LOCAL_HOST:$LOCAL_PORT found"
	echo "command:"
	echo "/usr/bin/snmpwalk -v 2c -c $COMMUNITY $LOCAL_HOST TCP-MIB::tcpConnState.$LOCAL_HOST.$LOCAL_PORT.$REMOTE_HOST"
	echo "OUTPUT: "
	echo "$OUTPUT"
	exit 1
fi

echo  "TCP Connection from $REMOTE_HOST to $LOCAL_HOST:$LOCAL_PORT found"
exit 0
