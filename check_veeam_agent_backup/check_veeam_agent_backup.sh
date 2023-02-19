#!/bin/sh

# Copyright 2017, Samúel Jón Gunnarsson
#
# check_veeam_agent_backup.sh is free software: you can redistribute
# it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# check_veeam_agent_backup.sh is distributed in the hope that it
# will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

output=$(veeamconfig session list --24 |grep Failed |wc -l)

if [ $output -eq 0 ]
then
    echo "OK- veeam backup, number of backups with error last 24hrs: $output"
    exit 0
elif [ $output -gt 0 ] && [ $output -le 3 ]
then
    echo "WARNING- veeam backup, number of backups with error last 24hrs: $output"
    exit 1
elif [ $output -eq 4 ]
then
    echo "CRITICAL- veeam backup, number of backups with error last 24hrs: $output"
    exit 2
else
    echo "UNKNOWN- veeam backup, number of backups with error last 24hrs: $output"
    exit 3
fi
