#!/bin/sh

#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

PROGNAME=`basename $0`
VERSION="Version 1.0,"
AUTHOR="2009, Mike Adolphs (http://www.matejunkie.com/)"

ST_OK=0
ST_WR=1
ST_CR=2
ST_UK=3

interval=1

print_version() {
    echo "$VERSION $AUTHOR"
}

print_help() {
    print_version $PROGNAME $VERSION
    echo ""
    echo "$PROGNAME is a Nagios plugin to monitor CPU utilization. It makes"
	echo "use of /proc/stat and calculates it through Jiffies rather than"
	echo "using another frontend tool like iostat or top."
	echo "When using optional warning/critical thresholds all values except"
	echo "idle are aggregated and compared to the thresholds. There's"
	echo "currently no support for warning/critical thresholds for specific"
	echo "usage parameters."
    echo ""
    echo "$PROGNAME [-i/--interval] [-w/--warning] [-c/--critical]"
    echo ""
    echo "Options:"
	echo "  --interval|-i)"
	echo "    Defines the pause between the two times /proc/stat is being"
	echo "    parsed. Higher values could lead to more accurate result."
	echo "    Default is: 1 second"
    echo "  --warning|-w)"
    echo "    Sets a warning level for CPU user. Default is: off"
    echo "  --critical|-c)"
    echo "    Sets a critical level for CPU user. Default is: off"
    exit $ST_UK
}

while test -n "$1"; do
    case "$1" in
        --help|-h)
            print_help
            exit $ST_UK
            ;;
        --version|-v)
            print_version $PROGNAME $VERSION
            exit $ST_UK
            ;;
        --interval|-i)
            interval=$2
            shift
            ;;
        --warning|-w)
            warn=$2
            shift
            ;;
        --critical|-c)
            crit=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_help
            exit $ST_UK
            ;;
    esac
    shift
done

val_wcdiff() {
    if [ ${warn} -gt ${crit} ]
    then
        wcdiff=1
    fi
}

get_cpuvals() {
	tmp1_cpu_user=`grep -m1 '^cpu' /proc/stat|awk '{print $2}'`
	tmp1_cpu_nice=`grep -m1 '^cpu' /proc/stat|awk '{print $3}'`
	tmp1_cpu_sys=`grep -m1 '^cpu' /proc/stat|awk '{print $4}'`
	tmp1_cpu_idle=`grep -m1 '^cpu' /proc/stat|awk '{print $5}'`
	tmp1_cpu_iowait=`grep -m1 '^cpu' /proc/stat|awk '{print $6}'`
	tmp1_cpu_irq=`grep -m1 '^cpu' /proc/stat|awk '{print $7}'`
	tmp1_cpu_softirq=`grep -m1 '^cpu' /proc/stat|awk '{print $8}'`
	tmp1_cpu_total=`expr $tmp1_cpu_user + $tmp1_cpu_nice + $tmp1_cpu_sys + \
$tmp1_cpu_idle + $tmp1_cpu_iowait + $tmp1_cpu_irq + $tmp1_cpu_softirq`

	sleep $interval

	tmp2_cpu_user=`grep -m1 '^cpu' /proc/stat|awk '{print $2}'`
	tmp2_cpu_nice=`grep -m1 '^cpu' /proc/stat|awk '{print $3}'`
	tmp2_cpu_sys=`grep -m1 '^cpu' /proc/stat|awk '{print $4}'`
	tmp2_cpu_idle=`grep -m1 '^cpu' /proc/stat|awk '{print $5}'`
	tmp2_cpu_iowait=`grep -m1 '^cpu' /proc/stat|awk '{print $6}'`
	tmp2_cpu_irq=`grep -m1 '^cpu' /proc/stat|awk '{print $7}'`
	tmp2_cpu_softirq=`grep -m1 '^cpu' /proc/stat|awk '{print $8}'`
	tmp2_cpu_total=`expr $tmp2_cpu_user + $tmp2_cpu_nice + $tmp2_cpu_sys + \
$tmp2_cpu_idle + $tmp2_cpu_iowait + $tmp2_cpu_irq + $tmp2_cpu_softirq`

	diff_cpu_user=`echo "${tmp2_cpu_user} - ${tmp1_cpu_user}" | bc -l`
	diff_cpu_nice=`echo "${tmp2_cpu_nice} - ${tmp1_cpu_nice}" | bc -l`
	diff_cpu_sys=`echo "${tmp2_cpu_sys} - ${tmp1_cpu_sys}" | bc -l`
	diff_cpu_idle=`echo "${tmp2_cpu_idle} - ${tmp1_cpu_idle}" | bc -l`
	diff_cpu_iowait=`echo "${tmp2_cpu_iowait} - ${tmp1_cpu_iowait}" | bc -l`
	diff_cpu_irq=`echo "${tmp2_cpu_irq} - ${tmp1_cpu_irq}" | bc -l`
	diff_cpu_softirq=`echo "${tmp2_cpu_softirq} - ${tmp1_cpu_softirq}" \
| bc -l`
	diff_cpu_total=`echo "${tmp2_cpu_total} - ${tmp1_cpu_total}" | bc -l`

	cpu_user=`echo "scale=2; (1000*${diff_cpu_user}/${diff_cpu_total}+5)/10" \
| bc -l | sed 's/^\./0./'`
	cpu_nice=`echo "scale=2; (1000*${diff_cpu_nice}/${diff_cpu_total}+5)/10" \
| bc -l | sed 's/^\./0./'`
	cpu_sys=`echo "scale=2; (1000*${diff_cpu_sys}/${diff_cpu_total}+5)/10" \
| bc -l | sed 's/^\./0./'`
	cpu_idle=`echo "scale=2; (1000*${diff_cpu_idle}/${diff_cpu_total}+5)/10" \
| bc -l | sed 's/^\./0./'`
	cpu_iowait=`echo "scale=2; (1000*${diff_cpu_iowait}/${diff_cpu_total}+5)\\
/10" | bc -l | sed 's/^\./0./'`
	cpu_irq=`echo "scale=2; (1000*${diff_cpu_irq}/${diff_cpu_total}+5)/10" \
| bc -l | sed 's/^\./0./'`
	cpu_softirq=`echo "scale=2; (1000*${diff_cpu_softirq}/${diff_cpu_total}\\
+5)/10" | bc -l | sed 's/^\./0./'`
	cpu_total=`echo "scale=2; (1000*${diff_cpu_total}/${diff_cpu_total}+5)\\
/10" | bc -l | sed 's/^\./0./'`
	cpu_usage=`echo "(${cpu_user}+${cpu_nice}+${cpu_sys}+${cpu_iowait}+\\
${cpu_irq}+${cpu_softirq})/1" | bc`
}

do_output() {
	output="user: ${cpu_user}, nice: ${cpu_nice}, sys: ${cpu_sys}, \
iowait: ${cpu_iowait}, irq: ${cpu_irq}, softirq: ${cpu_softirq} \
idle: ${cpu_idle}"
}

do_perfdata() {
	perfdata="'user'=${cpu_user} 'nice'=${cpu_nice} 'sys'=${cpu_sys} \
'softirq'=${cpu_softirq} 'iowait'=${cpu_iowait} 'irq'=${cpu_irq} \
'idle'=${cpu_idle}"
}

if [ -n "$warn" -a -n "$crit" ]
then
    val_wcdiff
    if [ "$wcdiff" = 1 ]
    then
		echo "Please adjust your warning/critical thresholds. The warning\\
must be lower than the critical level!"
        exit $ST_UK
    fi
fi

get_cpuvals
do_output
do_perfdata

if [ -n "$warn" -a -n "$crit" ]
then
    if [ "$cpu_usage" -ge "$warn" -a "$cpu_usage" -lt "$crit" ]
    then
		echo "WARNING - ${output} | ${perfdata}"
        exit $ST_WR
    elif [ "$cpu_usage" -ge "$crit" ]
    then
		echo "CRITICAL - ${output} | ${perfdata}"
        exit $ST_CR
    else
		echo "OK - ${output} | ${perfdata}"
        exit $ST_OK
    fi
else
	echo "OK - ${output} | ${perfdata}"
    exit $ST_OK
fi
