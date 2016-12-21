#!/bin/bash

EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2

PATH=/sbin:/usr/sbin:$PATH

if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 1>&2
	exit $EXIT_CRIT
fi

blocks=$(iptables -L -v -n | egrep 'REJECT|DROP' | wc -l)

if [ $blocks -eq 0 ]; then
	echo "CRITICAL: No firewall detected"
	exit $EXIT_CRIT
fi

echo "OK: Firewall is active"
exit $EXIT_OK

