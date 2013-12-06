CURRENT_PATH=`pwd`
cd $CURRENT_PATH/tests/ok
tests=`echo * | sed 's/.txt//g'`
for i in $tests ; do
	command="python $CURRENT_PATH/check_storwize.py --test -H testhost -U nagios -Q $i"
	$command > /dev/null 2>&1
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		echo "FAIL"
		echo "cd `pwd`"
		echo "Command: $command"
	else
		echo "$i working as expected"
	fi 
done


cd $CURRENT_PATH/tests/critical
tests=`echo * | sed 's/.txt//g'`
for i in $tests ; do
	command="python $CURRENT_PATH/check_storwize.py --test -H testhost -U nagios -Q $i"
	$command > /dev/null 2>&1
	RESULT=$?
	if [ $RESULT -ne 2 ]; then
		echo "FAIL"
		echo "cd `pwd`"
		echo "Command: $command"
	else
		echo "$i working as expected"
	fi 
done


