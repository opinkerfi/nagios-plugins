<?php
#
# Copyright (c) 2006-2008 Joerg Linge (http://www.pnp4nagios.org)
# $Id: check_oracle_health_connection-time.php 523 2008-09-26 17:10:20Z pitchfork $
#

foreach ($DS as $i) {
    if(preg_match('/^connection_time/', $NAME[$i])) {
        $ds_name[1] = "Connection Time";
        $opt[1] = "--vertical-label \"Connection Time\" --title \"Connection Time $hostname / $servicedesc\" ";
        $def[1] =  "DEF:var1=$rrdfile:$DS[1]:AVERAGE " ;
        $def[1] .= "AREA:var1#F2F2F2:\"\" " ;
        $def[1] .= "LINE1:var1#F30000:\"Connection Time\" " ;
        $def[1] .= "GPRINT:var1:LAST:\"%3.2lf LAST \" "; 
        $def[1] .= "GPRINT:var1:MAX:\"%3.2lf MAX \" "; 
        $def[1] .= "GPRINT:var1:AVERAGE:\"%3.2lf AVERAGE \" "; 
    }
    if(preg_match('/^tbs_.*_usage_pct/', $NAME[$i])) {
        # if exists array tbss && > 0 -> next
        if(isset($tbss)) continue;
        # hash bauen mit tablespace als key
        $tbss = array();
        $dsnr = array();
        $units = array();
        foreach ($DS as $t) {
            if(preg_match('/^tbs_(.*)_usage_pct/', $NAME[$t], $match)) {
              $tbss[] = $match[1];
            }
            $dsnr[] = $DS[$t];
            $units[] = $UNIT[$t];
            $warn[] = $WARN[$t];
            $crit[] = $CRIT[$t];
        }
        foreach ($tbss as $key => $tbs) {
            $ds_usage_pct = $dsnr[$key * 3];
            $ds_used = $dsnr[$key * 3 + 1];
            $ds_alloc = $dsnr[$key * 3 + 2];
            $unit_usage_pct = $units[$key * 3];
            $unit_used = $units[$key * 3 + 1];
            $unit_alloc = $units[$key * 3 + 2];
            #$warn_usage_pct = $warn[$key * 3];
            #$warn_used = $warn[$key * 3 + 1];
            #$warn_alloc = $warn[$key * 3 + 2];
            #$crit_usage_pct = $crit[$key * 3];
            #$crit_used = $crit[$key * 3 + 1];
            #$crit_alloc = $crit[$key * 3 + 2];
            $graph1 = $key * 2 + 1;
            $graph2 = $key * 2 + 2;
            $opt[$graph1] = "--vertical-label \"TBS usage %\" -u102 -l0 --title \"Tablespace $tbs usage $servicedesc\" ";
            $ds_name[$graph1] = "TBS usage %";
            $def[$graph1] =  "DEF:var1=$rrdfile:".$ds_usage_pct.":AVERAGE " ;
            $def[$graph1] .= "AREA:var1#F2F2F2:\"\" " ;
            $def[$graph1] .= "LINE1:var1#FF6600:\"used %\" " ;
            $def[$graph1] .= "GPRINT:var1:LAST:\"%3.2lf %% LAST \" ";
            $def[$graph1] .= "GPRINT:var1:MAX:\"%3.2lf %% MAX \" ";
            $def[$graph1] .= "GPRINT:var1:AVERAGE:\"%3.2lf %% AVERAGE \" ";
            if ($warn_usage_pct != "") {
                $def[$graph1] .= "HRULE:$warn_usage_pct#FFFF00 ";
            }
            if ($crit_usage_pct != "") {
                $def[$graph1] .= "HRULE:$crit_usage_pct#FF0000 ";
            }
            $opt[$graph2] = " -X 0 --vertical-label \"TBS usage $unit_used\" --title \"Tablespace $tbs usage $servicedesc\" ";
            $ds_name[$graph2] = "TBS usage ".$unit_used;
            $def[$graph2] =  "DEF:var1=$rrdfile:$ds_used:AVERAGE " ;
            $def[$graph2] .= "DEF:var2=$rrdfile:$ds_alloc:AVERAGE " ;
            $def[$graph2] .= "AREA:var2#F2F2F2:\"\" " ;
            $def[$graph2] .= "AREA:var1#C3C3C3:\"\" " ;
            $def[$graph2] .= "LINE1:var2#F30000:\"alloc ".$unit_alloc."\" " ;
            $def[$graph2] .= "GPRINT:var2:LAST:\"%6.2lf ".$unit_alloc." LAST \" ";
            $def[$graph2] .= "GPRINT:var2:MAX:\"%6.2lf ".$unit_alloc." MAX \" ";
            $def[$graph2] .= "GPRINT:var2:AVERAGE:\"%6.2lf ".$unit_alloc." AVERAGE \\n\" ";
            $def[$graph2] .= "LINE1:var1#FF6600:\"used ".$unit_used."\" " ;
            $def[$graph2] .= "GPRINT:var1:LAST:\"%6.2lf ".$unit_used." LAST \" ";
            $def[$graph2] .= "GPRINT:var1:MAX:\"%6.2lf ".$unit_used." MAX \" ";
            $def[$graph2] .= "GPRINT:var1:AVERAGE:\"%6.2lf ".$unit_used." AVERAGE \\n\" ";
        }
    }
}


# <?php
# #
# # Copyright (c) 2006-2008 Joerg Linge (http://www.pnp4nagios.org)
# # Default Template used if no other template is found.
# # Don`t delete this file ! 
# # $Id: default.php 367 2008-01-23 18:10:31Z pitchfork $
# #
# #
# # Define some colors ..
# #
# define("_WARNRULE", '#FFFF00');
# define("_CRITRULE", '#FF0000');
# define("_AREA", '#EACC00');
# define("_LINE", '#000000');
# #
# # Inital Logic ...
# #
# 
# foreach ($DS as $i) {
# 
# 	$warning = "";
# 	$minimum = "";
# 	$critical = "";
# 	$warning = "";
# 	$vlabel = "";
# 	
# 	if ($WARN[$i] != "") {
# 		$warning = $WARN[$i];
# 	}
# 	if ($CRIT[$i] != "") {
# 		$critical = $CRIT[$i];
# 	}
# 	if ($MIN[$i] != "") {
# 		$lower = " --lower=" . $MIN[$i];
# 		$minimum = $MIN[$i];
# 	}
# 	if ($CRIT[$i] != "") {
# 		$upper = " --upper=" . $MAX[$i];
# 		$maximum = $MAX[$i];
# 	}
# 	if ($UNIT[$i] == "%%") {
# 		$vlabel = "%";
# 	}
# 	else {
# 		$vlabel = $UNIT[$i];
# 	}
# 
# 	$opt[$i] = '--vertical-label "' . $vlabel . '" --title "' . $hostname . ' / ' . $servicedesc . '"' . $lower;
# 
# 	$def[$i] = "DEF:var1=$rrdfile:$DS[$i]:AVERAGE ";
# 	$def[$i] .= "AREA:var1" . _AREA . ":\"$NAME[$i] \" ";
# 	$def[$i] .= "LINE1:var1" . _LINE . ":\"\" ";
# 	$def[$i] .= "GPRINT:var1:LAST:\"%3.4lf %s$UNIT[$i] LAST \" ";
# 	$def[$i] .= "GPRINT:var1:MAX:\"%3.4lf %s$UNIT[$i] MAX \" ";
# 	$def[$i] .= "GPRINT:var1:AVERAGE:\"%3.4lf %s$UNIT[$i] AVERAGE \\n\" ";
# 	if ($warning != "") {
# 		$def[$i] .= "HRULE:" . $warning . _WARNRULE . ':"Warning on  ' . $warning . '\n" ';
# 	}
# 	if ($critical != "") {
# 		$def[$i] .= "HRULE:" . $critical . _CRITRULE . ':"Critical on ' . $critical . '\n" ';
# 	}
# 	$def[$i] .= 'COMMENT:"Default Template\r" ';
# 	$def[$i] .= 'COMMENT:"Check Command ' . $TEMPLATE[$i] . '\r" ';
# }
# ?>

?>
