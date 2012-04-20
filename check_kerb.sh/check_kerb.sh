#!/bin/bash

# Copyright 2010, Tomas Edwardsson 
#
# check_kerb.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# check_kerb.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


KRBUSER=$1
KRBPASS=$2

if [ -z $KRBPASS ]; then
	echo "Usage $0 <username> <password>"
	exit 3
fi

OUT=`echo $KRBPASS | kinit "$KRBUSER" 2>&1`
if [ $? -gt 0 ]; then
        echo "Unable to initiate kerberos session: $OUT"
        exit 2
else
        echo "Kerberos session initiated: $OUT"
        /usr/kerberos/bin/kdestroy &> /dev/null
        exit 0
fi


