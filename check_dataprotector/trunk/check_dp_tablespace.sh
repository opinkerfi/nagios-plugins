#!/bin/sh
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
# This script checks the tablespaces of HP dataprotector with the
# omnirpt -report db_size command. Issues a warning if database
# free space is running out


#/opt/omni/bin/omnirpt -report db_size 

echo $USER > /tmp/check_dp_tablespace.debug
echo $@ >> /tmp/check_dp_tablespace.debug


OUTPUT=$(/opt/omni/bin/omnirpt -report db_size)
RESULT=$?

if [ $RESULT -gt 0 ]; then
	echo -n $OUTPUT
	exit 1
fi
echo $OUTPUT | grep -q "No database devices with low disk space."

RESULT=$?

if [ $RESULT -gt 0 ]; then
	echo "Warning - Some dataprotector tablespaces are running low"
	exit 1
else
	echo "OK - No database devices with low disk space."
	exit 0
fi

