#!/bin/sh

# ./check_cisco_qos.pl -H  10.18.0.114 -C KB816af -w 10 -c 20  -i ALL -m Call_Signaling

PATH=$PATH:/usr/lib/nagios/plugins/:/usr/lib64/nagios/plugins/:/nagios/usr/lib/nagios/plugins
which check_cisco_qos.pl > /dev/null
if [ $? -gt 0 ]; then
	echo "Unknown check_cisco_qos.pl not found in path"
	exit 3
fi

CLASSES=`check_cisco_qos.pl $@ -i ALL -m ALL -d | grep qos-class| awk '{ print $6 }'`
NUM_CLASSES=`echo $CLASSES |wc -w`
if [ $NUM_CLASSES -lt 1 ]; then
	echo "Error running check_cisco_qos.pl"
	echo "Command was: check_cisco_qos.pl $@ -i ALL -m ALL -d"
	exit 3
fi

EXIT_CODE=0
for i in $CLASSES ; do
	TMP=`check_cisco_qos.pl $@ -i ALL -m $i`
	STATUS=$?
	if [ $STATUS -gt $EXIT_CODE ]; then
		EXIT_CODE=$STATUS
	fi
	SUMMARY="$SUMMARY $i"
	PERF=`echo $TMP | awk -F \| '{print $2 }' | sed "s/Sent/${i}_Sent/" | sed "s/Dropped/${i}_Dropped/"`
	PERFDATA="$PERFDATA $PERF"
done


test $EXIT_CODE == 0 && SUMMARY="OK - $SUMMARY"
test $EXIT_CODE == 1 && SUMMARY="WARNING - $SUMMARY"
test $EXIT_CODE == 2 && SUMMARY="CRITICAL - $SUMMARY"
echo "$SUMMARY | $PERFDATA"
exit $EXIT_CODE
