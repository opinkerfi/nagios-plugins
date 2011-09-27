<?php
#
# Copyright (c) 2009 Gerhard Lausser (gerhard.lausser@consol.de)
# Plugin: check_mysql_health (http://www.consol.com/opensource/nagios/check-mysql-health)
# Release 1.0 2009-03-02
#
# This is a template for the visualisation addon PNP (http://www.pnp4nagios.org)
#

$defcnt = 1;

$green = "33FF00E0";
$yellow = "FFFF00E0";
$red = "F83838E0";
$now = "FF00FF";

foreach ($DS as $i) {
    $warning = ($WARN[$i] != "") ? $WARN[$i] : "";
    $warnmin = ($WARN_MIN[$i] != "") ? $WARN_MIN[$i] : "";
    $warnmax = ($WARN_MAX[$i] != "") ? $WARN_MAX[$i] : "";
    $critical = ($CRIT[$i] != "") ? $CRIT[$i] : "";
    $critmin = ($CRIT_MIN[$i] != "") ? $CRIT_MIN[$i] : "";
    $critmax = ($CRIT_MAX[$i] != "") ? $CRIT_MAX[$i] : "";
    $minimum = ($MIN[$i] != "") ? $MIN[$i] : "";
    $maximum = ($MAX[$i] != "") ? $MAX[$i] : "";

    if(preg_match('/^connection_time$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Time to connect";
        $opt[$defcnt] = "--vertical-label \"Seconds\" --title \"Time to establish a connection to $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:connectiontime=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "AREA:connectiontime#111111 ";
        $def[$defcnt] .= "VDEF:vconnetiontime=connectiontime,LAST " ;
        $def[$defcnt] .= "GPRINT:vconnetiontime:\"is %3.2lf Seconds \" " ;
        $defcnt++;
    }
    if(preg_match('/^cpu_busy$/', $NAME[$i])) {
        $ds_name[$defcnt] = "CPU Busy Time";
        $opt[$defcnt] = "--vertical-label \"%\" --title \"CPU busy time on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:cpubusy=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=cpubusy,$WARN[$i],LE,cpubusy,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,cpubusy,0,IF ";
        $def[$defcnt] .= "CDEF:ay=cpubusy,$CRIT[$i],LE,cpubusy,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,cpubusy,0,IF ";
        $def[$defcnt] .= "CDEF:ar=cpubusy,100,LE,cpubusy,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,cpubusy,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:cpubusy#111111:\" \" ";
        $def[$defcnt] .= "VDEF:vcpubusy=cpubusy,LAST " ;
        $def[$defcnt] .= "GPRINT:vcpubusy:\"CPU is busy for %3.2lf percent of the time\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^io_busy$/', $NAME[$i])) {
        $ds_name[$defcnt] = "IO Busy Time";
        $opt[$defcnt] = "--vertical-label \"%\" --title \"IO busy time on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:iobusy=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=iobusy,$WARN[$i],LE,iobusy,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,iobusy,0,IF ";
        $def[$defcnt] .= "CDEF:ay=iobusy,$CRIT[$i],LE,iobusy,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,iobusy,0,IF ";
        $def[$defcnt] .= "CDEF:ar=iobusy,100,LE,iobusy,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,iobusy,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:iobusy#111111:\" \" ";
        $def[$defcnt] .= "VDEF:viobusy=iobusy,LAST " ;
        $def[$defcnt] .= "GPRINT:viobusy:\"IO is busy for %3.2lf percent of the time\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^full_scans_per_sec$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Full Table Scans / Sec";
        $opt[$defcnt] = "--vertical-label \"scans / sec\" --title \"Full table scans / sec on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:fullscans=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=fullscans,$WARN[$i],LE,fullscans,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,fullscans,0,IF ";
        $def[$defcnt] .= "CDEF:ay=fullscans,$CRIT[$i],LE,fullscans,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,fullscans,0,IF ";
        $def[$defcnt] .= "CDEF:ar=fullscans,INF,LE,fullscans,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,fullscans,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:fullscans#000000:\" \" ";
        $def[$defcnt] .= "VDEF:vfullscans=fullscans,LAST " ;
        $def[$defcnt] .= "GPRINT:vfullscans:\"%3.2lf full table scans / sec\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^connected_users$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Connected Users";
        $opt[$defcnt] = "--vertical-label \"Users\" --title \"Users connected to $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:users=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=users,$WARN[$i],LE,users,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,users,0,IF ";
        $def[$defcnt] .= "CDEF:ay=users,$CRIT[$i],LE,users,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,users,0,IF ";
        $def[$defcnt] .= "CDEF:ar=users,INF,LE,users,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,users,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:users#000000:\"connected users \" ";
        $def[$defcnt] .= "VDEF:lvusers=users,LAST " ;
        $def[$defcnt] .= "VDEF:mvusers=users,MAXIMUM " ;
        $def[$defcnt] .= "VDEF:avusers=users,AVERAGE " ;
        $def[$defcnt] .= "GPRINT:lvusers:\"%.0lf LAST \" " ;
        $def[$defcnt] .= "GPRINT:mvusers:\"%.0lf MAX \" " ;
        $def[$defcnt] .= "GPRINT:avusers:\"%.0lf AVERAGE \" " ;
        $defcnt++;
    }
    if(preg_match('/^.*_transactions_per_sec/', $NAME[$i])) {
        # if exists array dbs && > 0 -> next
        if(isset($dbs)) continue; # da muss rein, dass $servicedesc schon gezeichnet wurde.
        # hash bauen mit database als key
        $dbs = array();
        $dsnr = array();
        $units = array();
        $numds = 1;
        $colors = array("#ff0000","#00ffff","#0000ff","#00ff00"); #.....fuer singlegraph
        $multigraph = 0;
        foreach ($DS as $t) {
            if(preg_match('/^(.*)_transactions_per_sec/', $NAME[$t], $match)) {
              $dbs[] = $match[1];
            }
            $dsnr[] = $DS[$t];
            $units[] = $UNIT[$t];
            $warn[] = $WARN[$t];
            $crit[] = $CRIT[$t];
        }
        foreach ($dbs as $key => $db) {
            $ds_transactions = $dsnr[$key * $numds];
            $units_transactions = $units[$key * $numds];
            $warn_transactions = $warn[$key * $numds];
            $crit_transactions = $crit[$key * $numds];
            # eine zweite ds wuerde so aussehen
            # $ds_used = $dsnr[$key * $numds + 1];
            # aber transactions hat nur 1 ds
            $ds_name[$defcnt] = "Transactions / sec of DB $db";
            $opt[$defcnt] = "--vertical-label \"Transactions/s\" -l0 --title \"Database $db transactions / sec\" ";
            $def[$defcnt] =  "DEF:trans=$rrdfile:".$ds_transactions.":AVERAGE " ;
            if ($multigraph) {
              $def[$defcnt] .= "CDEF:ag=trans,$WARN[$i],LE,trans,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,trans,0,IF ";
              $def[$defcnt] .= "CDEF:ay=trans,$CRIT[$i],LE,trans,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,trans,0,IF ";
              $def[$defcnt] .= "CDEF:ar=trans,100,LE,trans,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,trans,0,IF ";
              $def[$defcnt] .= "AREA:ag#$green: " ;
              $def[$defcnt] .= "AREA:ay#$yellow: " ;
              $def[$defcnt] .= "AREA:ar#$red: " ;
              $def[$defcnt] .= "LINE0.6:trans#000000:\"$db\" " ;
            } else {
              $def[$defcnt] =  "DEF:trans=$rrdfile:".$ds_transactions.":AVERAGE " ;
              $def[$defcnt] .= "AREA:trans#F2F2F2:\"\" " ;
              $def[$defcnt] .= "LINE1:trans$colors[$multigraph]:\"$db\" " ;
            }
            $def[$defcnt] .= "GPRINT:trans:LAST:\"%3.2lf/s LAST \" ";
            $def[$defcnt] .= "GPRINT:trans:MAX:\"%3.2lf/s MAX \" ";
            $def[$defcnt] .= "GPRINT:trans:AVERAGE:\"%3.2lf/s AVERAGE \\n\" ";
            if ($multigraph) {
              $defcnt++;
            }
        }
    }
    if(preg_match('/^latch_waits_per_sec$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Latch Waits / Sec";
        $opt[$defcnt] = "--vertical-label \"waits / sec\" --title \"Latch waits / sec on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:waits=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=waits,$WARN[$i],LE,waits,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,waits,0,IF ";
        $def[$defcnt] .= "CDEF:ay=waits,$CRIT[$i],LE,waits,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,waits,0,IF ";
        $def[$defcnt] .= "CDEF:ar=waits,INF,LE,waits,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,waits,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:waits#000000:\" \" ";
        $def[$defcnt] .= "VDEF:vwaits=waits,LAST " ;
        $def[$defcnt] .= "GPRINT:vwaits:\"%3.2lf waits / sec\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^latch_avg_wait_time$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Latch Wait Time";
        $opt[$defcnt] = "--vertical-label \"msec\" --title \"Latch avg wait time on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:waittime=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=waittime,$WARN[$i],LE,waittime,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,waittime,0,IF ";
        $def[$defcnt] .= "CDEF:ay=waittime,$CRIT[$i],LE,waittime,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,waittime,0,IF ";
        $def[$defcnt] .= "CDEF:ar=waittime,INF,LE,waittime,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,waittime,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:waittime#000000:\" \" ";
        $def[$defcnt] .= "VDEF:vwaittime=waittime,LAST " ;
        $def[$defcnt] .= "GPRINT:vwaittime:\"%3.2lf waittime (milliseconds)\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^sql_initcompilations_per_sec$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Initial Compilations";
        $opt[$defcnt] = "--vertical-label \"initcomps/s\" --title \"Initial compilations / sec on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:comps=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=comps,$WARN[$i],LE,comps,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,comps,0,IF ";
        $def[$defcnt] .= "CDEF:ay=comps,$CRIT[$i],LE,comps,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,comps,0,IF ";
        $def[$defcnt] .= "CDEF:ar=comps,INF,LE,comps,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,comps,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:comps#000000:\" \" ";
        $def[$defcnt] .= "VDEF:vcomps=comps,LAST " ;
        $def[$defcnt] .= "GPRINT:vcomps:\"%3.2lf initial compilations / sec\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^sql_recompilations_per_sec$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Re-Compilations";
        $opt[$defcnt] = "--vertical-label \"re-comps/s\" --title \"Re-Compilations / sec on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:comps=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=comps,$WARN[$i],LE,comps,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,comps,0,IF ";
        $def[$defcnt] .= "CDEF:ay=comps,$CRIT[$i],LE,comps,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,comps,0,IF ";
        $def[$defcnt] .= "CDEF:ar=comps,INF,LE,comps,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,comps,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:comps#000000:\" \" ";
        $def[$defcnt] .= "VDEF:vcomps=comps,LAST " ;
        $def[$defcnt] .= "GPRINT:vcomps:\"%3.2lf re-compilations / sec\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^batch_requests_per_sec$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Batch Requests";
        $opt[$defcnt] = "--vertical-label \"batchreqs/s\" --title \"Batch requests / sec on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:breqs=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=breqs,$WARN[$i],LE,breqs,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,breqs,0,IF ";
        $def[$defcnt] .= "CDEF:ay=breqs,$CRIT[$i],LE,breqs,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,breqs,0,IF ";
        $def[$defcnt] .= "CDEF:ar=breqs,INF,LE,breqs,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,breqs,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:breqs#000000:\" \" ";
        $def[$defcnt] .= "VDEF:lvbreqs=breqs,LAST " ;
        $def[$defcnt] .= "VDEF:avbreqs=breqs,AVERAGE " ;
        $def[$defcnt] .= "VDEF:mvbreqs=breqs,MAXIMUM " ;
        $def[$defcnt] .= "GPRINT:lvbreqs:\"%3.2lf batch requests / sec \" " ;
        $def[$defcnt] .= "GPRINT:avbreqs:\"(AVERAGE\: %3.2lf\" " ;
        $def[$defcnt] .= "GPRINT:mvbreqs:\"MAX %3.2lf)\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^checkpoint_pages_per_sec$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Checpoint Pages";
        $opt[$defcnt] = "--vertical-label \"pages/s\" --title \"Flushed pages / sec on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:pages=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=pages,$WARN[$i],LE,pages,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,pages,0,IF ";
        $def[$defcnt] .= "CDEF:ay=pages,$CRIT[$i],LE,pages,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,pages,0,IF ";
        $def[$defcnt] .= "CDEF:ar=pages,INF,LE,pages,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,pages,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:pages#000000:\" \" ";
        $def[$defcnt] .= "VDEF:lvpages=pages,LAST " ;
        $def[$defcnt] .= "VDEF:avpages=pages,AVERAGE " ;
        $def[$defcnt] .= "VDEF:mvpages=pages,MAXIMUM " ;
        $def[$defcnt] .= "GPRINT:lvpages:\"%3.2lf pages flushed / sec \" " ;
        $def[$defcnt] .= "GPRINT:avpages:\"(AVERAGE\: %3.2lf\" " ;
        $def[$defcnt] .= "GPRINT:mvpages:\"MAX %3.2lf)\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^free_list_stalls_per_sec$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Free List Stalls";
        $opt[$defcnt] = "--vertical-label \"stalls/s\" --title \"Free list stalls / sec on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:stalls=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=stalls,$WARN[$i],LE,stalls,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,stalls,0,IF ";
        $def[$defcnt] .= "CDEF:ay=stalls,$CRIT[$i],LE,stalls,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,stalls,0,IF ";
        $def[$defcnt] .= "CDEF:ar=stalls,INF,LE,stalls,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,stalls,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:stalls#000000:\" \" ";
        $def[$defcnt] .= "VDEF:lvstalls=stalls,LAST " ;
        $def[$defcnt] .= "VDEF:avstalls=stalls,AVERAGE " ;
        $def[$defcnt] .= "VDEF:mvstalls=stalls,MAXIMUM " ;
        $def[$defcnt] .= "GPRINT:lvstalls:\"%3.2lf free list stalls / sec \" " ;
        $def[$defcnt] .= "GPRINT:avstalls:\"(AVERAGE\: %3.2lf\" " ;
        $def[$defcnt] .= "GPRINT:mvstalls:\"MAX %3.2lf)\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^lazy_writes_per_sec$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Lazy Writes";
        $opt[$defcnt] = "--vertical-label \"lazyw/s\" --title \"Lazy writes / sec on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:lazyw=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ag=lazyw,$WARN[$i],LE,lazyw,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,lazyw,0,IF ";
        $def[$defcnt] .= "CDEF:ay=lazyw,$CRIT[$i],LE,lazyw,$WARN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,lazyw,0,IF ";
        $def[$defcnt] .= "CDEF:ar=lazyw,INF,LE,lazyw,$CRIT[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,lazyw,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:lazyw#000000:\" \" ";
        $def[$defcnt] .= "VDEF:lvlazyw=lazyw,LAST " ;
        $def[$defcnt] .= "VDEF:avlazyw=lazyw,AVERAGE " ;
        $def[$defcnt] .= "VDEF:mvlazyw=lazyw,MAXIMUM " ;
        $def[$defcnt] .= "GPRINT:lvlazyw:\"%3.2lf lazy writes / sec \" " ;
        $def[$defcnt] .= "GPRINT:avlazyw:\"(AVERAGE\: %3.2lf\" " ;
        $def[$defcnt] .= "GPRINT:mvlazyw:\"MAX %3.2lf)\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^page_life_expectancy$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Page Life Expectancy";
        $opt[$defcnt] = "--vertical-label \"s\" --title \"Page life expectancy on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:lifeexp=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ar=lifeexp,$CRIT_MIN[$i],LE,lifeexp,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,lifeexp,0,IF ";
        $def[$defcnt] .= "CDEF:ay=lifeexp,$WARN_MIN[$i],LE,lifeexp,$CRIT_MIN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,lifeexp,0,IF ";
        $def[$defcnt] .= "CDEF:ag=lifeexp,INF,LE,lifeexp,$WARN_MIN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,lifeexp,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:lifeexp#000000:\" \" ";
        $def[$defcnt] .= "VDEF:lvlifeexp=lifeexp,LAST " ;
        $def[$defcnt] .= "VDEF:avlifeexp=lifeexp,AVERAGE " ;
        $def[$defcnt] .= "VDEF:mvlifeexp=lifeexp,MINIMUM " ;
        $def[$defcnt] .= "GPRINT:lvlifeexp:\"Page life expectancy is %3.2lf seconds \" " ;
        $def[$defcnt] .= "GPRINT:avlifeexp:\"(AVERAGE\: %3.2lf\" " ;
        $def[$defcnt] .= "GPRINT:mvlifeexp:\"MIN %3.2lf)\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^total_server_memory$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Total Server memory";
        $opt[$defcnt] = "--vertical-label \"Bytes\" --title \"Total sql server memory on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:threads=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "AREA:threads#111111 ";
        $def[$defcnt] .= "VDEF:vthreads=threads,LAST " ;
        $def[$defcnt] .= "GPRINT:vthreads:\"%.0lf Bytes \" " ;
        $defcnt++;
    }
    if(preg_match('/^buffer_cache_hit_ratio$/', $NAME[$i])) {
        $ds_name[$defcnt] = "Buffer Cache Hit Ratio";
        $opt[$defcnt] = "--vertical-label \"%\" --title \"Buffer cache hit ratio on $hostname\" ";
        $def[$defcnt] = "";
        $def[$defcnt] .= "DEF:bufcahitrat=$rrdfile:$DS[$i]:AVERAGE:reduce=LAST " ;
        $def[$defcnt] .= "CDEF:ar=bufcahitrat,$CRIT_MIN[$i],LE,bufcahitrat,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,bufcahitrat,0,IF ";
        $def[$defcnt] .= "CDEF:ay=bufcahitrat,$WARN_MIN[$i],LE,bufcahitrat,$CRIT_MIN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,bufcahitrat,0,IF ";
        $def[$defcnt] .= "CDEF:ag=bufcahitrat,100,LE,bufcahitrat,$WARN_MIN[$i],GT,INF,UNKN,IF,UNKN,IF,ISINF,bufcahitrat,0,IF ";
        $def[$defcnt] .= "AREA:ag#$green: " ;
        $def[$defcnt] .= "AREA:ay#$yellow: " ;
        $def[$defcnt] .= "AREA:ar#$red: " ;
        $def[$defcnt] .= "LINE0.6:bufcahitrat#000000:\" \" ";
        $def[$defcnt] .= "VDEF:vbufcahitrat=bufcahitrat,LAST " ;
        $def[$defcnt] .= "GPRINT:vbufcahitrat:\"Hit ratio is %3.2lf percent\\n\" " ;
        $defcnt++;
    }
    if(preg_match('/^.*_lock_timeouts_per_sec/', $NAME[$i])) {
        # if exists array locks && > 0 -> next
        if(isset($locks)) continue;
        # hash bauen mit tablespace als key
        $locks = array();
        $dsnr = array();
        $units = array();
        $numds = 2;
        foreach ($DS as $t) {
            if(preg_match('/^(.*)_lock_timeouts_per_sec/', $NAME[$t], $match)) {
              $locks[] = $match[1];
            }
            $dsnr[] = $DS[$t];
            $units[] = $UNIT[$t];
            $warn[] = $WARN[$t];
            $crit[] = $CRIT[$t];
            $warn_min[] = $WARN_MIN[$t];
            $crit_min[] = $CRIT_MIN[$t];
        }
        foreach ($locks as $key => $lock) {
            $lock_timeouts_per_sec = $dsnr[$key * $numds];
            $unit_lock_timeouts_per_sec = $units[$key * $numds];
            $warn= $warn[$key * $numds];
            $crit= $crit[$key * $numds];

            $ds_name[$defcnt] = "Lock Timeouts Per Second";
            $opt[$defcnt] = "--vertical-label \"timeouts / sec\" -l0 --title \"Timeouts / sec for lock $lock on $hostname \" ";
            $def[$defcnt] =  "DEF:timeouts=$rrdfile:".$lock_timeouts_per_sec.":AVERAGE " ;
            $def[$defcnt] .= "CDEF:ag=timeouts,$warn,LE,timeouts,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,timeouts,0,IF ";
            $def[$defcnt] .= "CDEF:ay=timeouts,$crit,LE,timeouts,$warn,GT,INF,UNKN,IF,UNKN,IF,ISINF,timeouts,0,IF ";
            $def[$defcnt] .= "CDEF:ar=timeouts,INF,LE,timeouts,$crit,GT,INF,UNKN,IF,UNKN,IF,ISINF,timeouts,0,IF ";
            $def[$defcnt] .= "AREA:ag#$green: " ;
            $def[$defcnt] .= "AREA:ay#$yellow: " ;
            $def[$defcnt] .= "AREA:ar#$red: " ;
            $def[$defcnt] .= "LINE0.6:timeouts#000000:\" \" ";
            $def[$defcnt] .= "VDEF:vtimeouts=timeouts,LAST " ;
            $def[$defcnt] .= "GPRINT:vtimeouts:\"%8.3lf timeouts / sec\" ";
            $defcnt++;
        }
    }
    if(preg_match('/^.*_lock_waits_per_sec/', $NAME[$i])) {
        # if exists array locks && > 0 -> next
        if(isset($locks)) continue;
        # hash bauen mit tablespace als key
        $locks = array();
        $dsnr = array();
        $units = array();
        $numds = 2;
        foreach ($DS as $t) {
            if(preg_match('/^(.*)_lock_waits_per_sec/', $NAME[$t], $match)) {
              $locks[] = $match[1];
            }
            $dsnr[] = $DS[$t];
            $units[] = $UNIT[$t];
            $warn[] = $WARN[$t];
            $crit[] = $CRIT[$t];
            $warn_min[] = $WARN_MIN[$t];
            $crit_min[] = $CRIT_MIN[$t];
        }
        foreach ($locks as $key => $lock) {
            $lock_waits_per_sec = $dsnr[$key * $numds];
            $unit_lock_waits_per_sec = $units[$key * $numds];
            $warn= $warn[$key * $numds];
            $crit= $crit[$key * $numds];

            $ds_name[$defcnt] = "Lock waits Per Second";
            $opt[$defcnt] = "--vertical-label \"waits / sec\" -l0 --title \"Waits / sec for lock $lock on $hostname \" ";
            $def[$defcnt] =  "DEF:waits=$rrdfile:".$lock_waits_per_sec.":AVERAGE " ;
            $def[$defcnt] .= "CDEF:ag=waits,$crit,LE,waits,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,waits,0,IF ";
            $def[$defcnt] .= "CDEF:ay=waits,$warn,LE,waits,$crit,GT,INF,UNKN,IF,UNKN,IF,ISINF,waits,0,IF ";
            $def[$defcnt] .= "CDEF:ar=waits,100,LE,waits,$warn,GT,INF,UNKN,IF,UNKN,IF,ISINF,waits,0,IF ";
            $def[$defcnt] .= "AREA:ag#$green: " ;
            $def[$defcnt] .= "AREA:ay#$yellow: " ;
            $def[$defcnt] .= "AREA:ar#$red: " ;
            $def[$defcnt] .= "LINE0.6:waits#000000:\" \" ";
            $defcnt++;
        }
    }
    if(preg_match('/^.*_deadlocks_per_sec/', $NAME[$i])) {
        # if exists array locks && > 0 -> next
        if(isset($locks)) continue;
        # hash bauen mit tablespace als key
        $locks = array();
        $dsnr = array();
        $units = array();
        $numds = 2;
        foreach ($DS as $t) {
            if(preg_match('/^(.*)_deadlocks_per_sec/', $NAME[$t], $match)) {
              $locks[] = $match[1];
            }
            $dsnr[] = $DS[$t];
            $units[] = $UNIT[$t];
            $warn[] = $WARN[$t];
            $crit[] = $CRIT[$t];
            $warn_min[] = $WARN_MIN[$t];
            $crit_min[] = $CRIT_MIN[$t];
        }
        foreach ($locks as $key => $lock) {
            $lock_deadlocks_per_sec = $dsnr[$key * $numds];
            $unit_lock_deadlocks_per_sec = $units[$key * $numds];
            $warn= $warn[$key * $numds];
            $crit= $crit[$key * $numds];

            $ds_name[$defcnt] = "Deadlocks Per Second";
            $opt[$defcnt] = "--vertical-label \"deadlocks / sec\" -l0 --title \"Deadlocks / sec for lock $lock on $hostname \" ";
            $def[$defcnt] =  "DEF:deadlocks=$rrdfile:".$lock_deadlocks_per_sec.":AVERAGE " ;
            $def[$defcnt] .= "CDEF:ag=deadlocks,$crit,LE,deadlocks,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,deadlocks,0,IF ";
            $def[$defcnt] .= "CDEF:ay=deadlocks,$warn,LE,deadlocks,$crit,GT,INF,UNKN,IF,UNKN,IF,ISINF,deadlocks,0,IF ";
            $def[$defcnt] .= "CDEF:ar=deadlocks,100,LE,deadlocks,$warn,GT,INF,UNKN,IF,UNKN,IF,ISINF,deadlocks,0,IF ";
            $def[$defcnt] .= "AREA:ag#$green: " ;
            $def[$defcnt] .= "AREA:ay#$yellow: " ;
            $def[$defcnt] .= "AREA:ar#$red: " ;
            $defcnt++;
        }
    }
    if(preg_match('/^db_.*_free_pct/', $NAME[$i])) {
        # if exists array dbs && > 0 -> next
        if(isset($dbs)) continue;
        # hash bauen mit tablespace als key
        $dbs = array();
        $dsnr = array();
        $units = array();
        $numds = 3;
        $colors = array("#000000","#00ffff","#0000ff");
        foreach ($DS as $t) {
            if(preg_match('/^db_(.*)_free_pct/', $NAME[$t], $match)) {
              $dbs[] = $match[1];
            }
            $dsnr[] = $DS[$t];
            $act[] = $ACT[$t];
            $units[] = $UNIT[$t];
            $warn[] = $WARN[$t];
            $crit[] = $CRIT[$t];
            $warn_min[] = $WARN_MIN[$t];
            $crit_min[] = $CRIT_MIN[$t];
            $max[] = $MAX[$t];
            $min[] = $MIN[$t];
        }
        foreach ($dbs as $key => $db) {
            $db_free_pct = $dsnr[$key * $numds];
            $db_free_mb = $dsnr[$key * $numds + 1];
            $db_free_mb_val = $act[$key * $numds + 1];
            $max_free_mb = $max[$key * $numds + 1];
            $db_alloc_pct = $dsnr[$key * $numds + 2];
            $unit_free_pct = $units[$key * $numds];
            $unit_free_mb = $units[$key * $numds + 1];
            $warn_free_pct = $warn_min[$key * $numds];
            $crit_free_pct = $crit_min[$key * $numds];

            $ds_name[$defcnt] = "DB free space %";
            $opt[$defcnt] = "--vertical-label \"DB free space %\" -u102 -l0 --title \"Database $db free space \" ";
            $def[$defcnt] =  "DEF:free=$rrdfile:".$db_free_pct.":AVERAGE " ;
            $def[$defcnt] .=  "DEF:allocated=$rrdfile:".$db_alloc_pct.":AVERAGE " ;
            $def[$defcnt] .=  "DEF:freemb=$rrdfile:".$db_free_mb.":AVERAGE " ;
            $def[$defcnt] .= "CDEF:ar=free,$crit_free_pct,LE,free,0,GT,INF,UNKN,IF,UNKN,IF,ISINF,free,0,IF ";
            $def[$defcnt] .= "CDEF:ay=free,$warn_free_pct,LE,free,$crit_free_pct,GT,INF,UNKN,IF,UNKN,IF,ISINF,free,0,IF ";
            $def[$defcnt] .= "CDEF:ag=free,100,LE,free,$warn_free_pct,GT,INF,UNKN,IF,UNKN,IF,ISINF,free,0,IF ";
            $def[$defcnt] .= "CDEF:used=100,free,- ";
            $def[$defcnt] .= "AREA:ag#$green: " ;
            $def[$defcnt] .= "AREA:ay#$yellow: " ;
            $def[$defcnt] .= "AREA:ar#$red: " ;
            $def[$defcnt] .= "LINE0.6:free#000000:\" \" ";
            $def[$defcnt] .= "AREA:used#00000030::STACK " ;
            $def[$defcnt] .= "VDEF:lvfree=free,LAST " ;
            $def[$defcnt] .= "VDEF:lvfreemb=freemb,LAST " ;
            $def[$defcnt] .= "GPRINT:lvfree:\"Database $db has %.2lf%% free space left \" ";
            $def[$defcnt] .= "COMMENT:\"($db_free_mb_val of $max_free_mb$unit_free_mb)\\n\" ";
            $def[$defcnt] .= "COMMENT:\"($warn_free_pct $crit_free_pct\" ";
            $def[$defcnt] .= "LINE1:allocated#FFFFFF:\" \" ";
            $def[$defcnt] .= "VDEF:lvallocated=allocated,LAST " ;
            $def[$defcnt] .= "GPRINT:lvallocated:\"Database $db has %.2lf%% allocated\\n\" ";
            $defcnt++;
        }
    }
}
if(isset($dbs)) unset($dbs);
if(isset($locks)) unset($locks);
if(isset($warn)) unset($warn);
if(isset($crit)) unset($crit);
?>

