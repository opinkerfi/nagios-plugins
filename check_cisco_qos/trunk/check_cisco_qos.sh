#!/bin/sh

# ./check_cisco_qos.pl -H  10.18.0.114 -C KB816af -w 10 -c 20  -i ALL -m Call_Signaling

CLASSES=`./check_cisco_qos.pl $@ -i ALL -m ALL -d | grep qos-class| awk '{ print $6 }'`
EXIT_CODE=0
for i in $CLASSES ; do
	TMP=`./check_cisco_qos.pl $@ -i ALL -m $i`
	STATUS=$?
	if [ $STATUS -gt $EXIT_CODE ]; then
		EXIT_CODE=$STATUS
	fi
	SUMMARY="$SUMMARY $i"
	PERF=`echo $TMP | awk -F \| '{print $2 }' | sed "s/Sent/${i}_Sent/" | sed "s/Dropped/${i}_Dropped/"`
	PERFDATA="$PERFDATA $PERF"
done

echo "$SUMMARY | $PERFDATA"

