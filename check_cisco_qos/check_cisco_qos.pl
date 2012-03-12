#!/usr/bin/perl -w
#
#    ---------------------------------------------------------------------------
#    Cisco QOS plugin for Nagios Copyright 2010 Lionel Cottin (cottin@free.fr)
#    ---------------------------------------------------------------------------
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#    ---------------------------------------------------------------------------
#
my $version = "0.2";
my $release = "2010/03/05";
#
# This plugin checks for the QOS status configured on Cisco routers.
# 
# 1. QOS summary mode
# -------------------
#   In this mode the plugin works as follows:
#    - get the entire QoS configuration.
#    - sum up all dropped traffic on all interfaces and all classes
#    - calculate the average drop rate in bits per second
#    - evaluate calculated drop rate against warning/critical thresholds
#    - return the corresponding Nagios status & performance data
#   
#   In order to use this mode you need to call the plugin using the
#   following command line arguments:
#   	-i ALL        <- i.e. check for all interfaces
#   	-m ALL        <- i.e. check for all QoS classes
#   	-w <warning drop rate in bits per second>
#   	-c <critical drop rate in bits per second>
#   
#   Example:
#     $ ./check_cisco_qos.pl -H 10.10.10.10 -C public -w 10 -c 20  -i ALL -m ALL
#     QOS: Total drop rate (0.00 bits/s) is below warning threshold (10 bits/s): OK
#     | Sent=62232.52Bits/s;Dropped=0.00Bits/s
# 
#   This mode is useful if you just want to know how much is dropped as a result
#   of QoS processing.
# 
# 2. Class summary mode
# ---------------------
#   In this mode the plugin works as follows:
#    - get the entire QoS configuration.
#    - sum up all dropped traffic on all interfaces for one specific QoS class
#    - calculate the average drop rate in bits per second
#    - evaluate calculated drop rate against warning/critical thresholds
#    - return the corresponding Nagios status & performance data
# 
#   In order to use this mode you need to call the plugin using the
#   following command line arguments:
#   	-i ALL        <- i.e. check for all interfaces
#   	-m <QoS class name>
#   	-w <warning drop rate in bits per second>
#   	-c <critical drop rate in bits per second>
#   
#   Example:
#     $ ./check_cisco_qos.pl -H 10.10.10.10 -C public -w 10 -c 20  -i ALL -m class-default
#     QOS: Total drop rate for class class-default (0.00 bits/s) is below warning threshold (10 bits/s): OK
#     | Sent=79310.40Bits/s;Dropped=0.00Bits/s
# 
#   This mode is useful when you have standard QoS policies deployed on multiple
#   routers with varying interface names. It allows to define one probe per QoS
#   class and to deploy it on multiple routers.
# 
# 3. Interface summary mode
# -------------------------
#   In this mode the plugin works as follows:
#    - get the entire QoS configuration.
#    - sum up all dropped traffic of all QoS classes on one specific interface
#    - calculate the average drop rate in bits per second
#    - evaluate calculated drop rate against warning/critical thresholds
#    - return the corresponding Nagios status & performance data
# 
#   In order to use this mode you need to call the plugin using the
#   following command line arguments:
#   	-i <interface name>
#   	-m ALL        <- i.e. check for all QoS classes
#   	-w <warning drop rate in bits per second>
#   	-c <critical drop rate in bits per second>
#   
#   Example:
#     # ./check_cisco_qos.pl -H 10.10.10.10 -C public -w 10 -c 20  -i MF1 -m ALL
#     QOS: Total drop rate on MF1 (33184.85 bits/s) is above critical threshold (20 bits/s): CRITICAL
#     | Sent=2208926.56Bits/s;Dropped=33184.85Bits/s
# 
#   This mode is useful to monitor dropped traffic per interface.
# 
# 4. Detailled mode
# -----------------
#   In this mode the plugin works as follows:
#    - get the entire QoS configuration.
#    - get dropped traffic of one QoS class on one specific interface
#    - calculate the average drop rate in bits per second
#    - evaluate calculated drop rate against warning/critical thresholds
#    - return the corresponding Nagios status & performance data
# 
#   In order to use this mode you need to call the plugin using the
#   following command line arguments:
#   	-i <interface name>
#   	-m <QoS class name>
#   	-w <warning drop rate in bits per second>
#   	-c <critical drop rate in bits per second>
# 
#   Example:
#     # ./check_cisco_qos.pl -H 10.10.10.10 -C public -w 10 -c 20  -i MF1 -m class-default
#     QOS: Drop rate for class-default on MF1 (1409 bits/s) is above critical threshold (20 bits/s): CRITICAL
#     | Sent=73395Bits/s;Dropped=1409Bits/s
# 
# 5. Notes
# --------
# 
#   Interface names:
#   ----------------
#   This plugin identifies interface names based on their short name like "Gi0/1".
#   You can run the plugin in debug mode using "-i ALL -m ALL -d" to find out
#   short interface names on your router.
# 
# 
#   Bit rate calculation:
#   ---------------------
#   The first time you run the plugin it will create a temporary file in /tmp
#   This file contains 3 lines:
#     - the last drop counter in bits  (lastDrop=XXXXXXX)
#     - the last sent counter in bits  (lastPost=XXXXXXX)
#     - the last epoch time in seconds (lastEpoch=XXXXXXX)
#   
#   The second time you run the plugin, it will compare actual values against
#   the previous ones and calculate the rates as follows:
#     - dropRate = (current drop counter - last drop counter) / (current epoch - last epoch)
#     - sentRate = (current post counter - last post counter) / (current epoch - last epoch)
#   
#   SNMP counters:
#   --------------
#   The SNMP counters being used are:
#     - cbQosCMDropByte (.1.3.6.1.4.1.9.9.166.1.15.1.1.16)
#       --> traffic dropped as a result of QoS processing
#     - cbQosCMPostPolicyByte (.1.3.6.1.4.1.9.9.166.1.15.1.1.9)
#       --> traffic sent after QoS processing
#
#   The Cisco QoS MIB (CISCO-CLASS-BASED-QOS-MIB) also provides some bit rate
#   counters but I had some weird results using them; that's why they are not used here.
#
#  Changelog:
#  ----------
#  - 0.1: Initial release
#  - 0.2: Fixed bit rate calculation when SNMP counter has wrapped
#
use Getopt::Std;
use Net::SNMP qw(:snmp);
#
my (
  %qos,
  %qos_interfaces,
  %qos_classes,
  %qos_policies,
  %qos_config,
  @classes,
  @polices,
  @class_index,
  @ifDescrarray,
  $class,
  $int,
  $ifDescr,
  $policy_index,
  $policy_name,
  $interface,
  $usage,
  $hostname,
  $community,
  $checkInterval,
  $ifCount,
  $ifSpeed,
  $long,
  $state,
  $message,
  $temp,
  $short,
  $perf,
  $fname,
  $tmp,
  $drop,
  $post,
  $epoch,
  $lastEpoch,
  $lastDrop,
  $lastPost,
  $postRate,
  $dropRate,
  $postCount,
  $dropCount
  );

################################################################################
###                             VARIABLES SECTION                            ###
################################################################################

my $ifDescr_oid           = ".1.3.6.1.2.1.2.2.1.2";
my $ifName_oid            = ".1.3.6.1.2.1.31.1.1.1.1";
my $ifSpeed_oid           = ".1.3.6.1.2.1.2.2.1.5";
my $class_name_oid        = ".1.3.6.1.4.1.9.9.166.1.7.1.1.1";  # qos classes
my $policy_name_oid       = ".1.3.6.1.4.1.9.9.166.1.6.1.1.1";  # qos policies
my $ifIndex_oid           = ".1.3.6.1.4.1.9.9.166.1.1.1.1.4";  # qos ifIndex
my $config_index_oid      = "1.3.6.1.4.1.9.9.166.1.5.1.1.2";   # qos references
my $cbQosCMDropByte       = ".1.3.6.1.4.1.9.9.166.1.15.1.1.16";# qos Drop bytes
my $cbQosCMPostPolicyByte = ".1.3.6.1.4.1.9.9.166.1.15.1.1.9"; # qos Post bytes

$tmp          = "/tmp";
$post         = 0;
$drop         = 0;
$postCount    = 0;
$dropCount    = 0;
$ifCount      = 0;
$state        = 3;
$long         = "";
$message      = "QOS: Default status: UNKNOWN\n";

$usage = <<"EOF";
usage:  $0 [-h] -H <hostname> -C <community> -i <interface> -m <qos-class> -w <warning> -c <critical> [-d]

Version: $version
Released on: $release

Nagios check for Cisco IP SLAs.
Checks for probe status and returns execution time
as perf data (multi-line output)

[-h]              :       Print this message
[-H] <router>     :       IP Address or Hostname of the router
[-C] <community>  :       SNMP Community String  (default = "public")
[-i] <interface>  :	  What interface do you want to check
			  ( "-i ALL" to check all interfaces)
[-m] <qos-class>  :       What class do you want to check
			  ( "-m ALL" to check all classes)
[-w]		  :	  Warning level in # of dropped packets or rate
			  depending on -i and -m options
[-c]		  :	  Critical level in # of dropped packes or rate
			  depending on -i and -m options
[-d]              :       enable debug output
 
EOF

################################################################################
###                               MAIN SECTION                               ###
################################################################################

#===============================================================================
#                              Input Phase
#===============================================================================
die $usage if (!getopts('hH:C:w:c:di:m:') || $opt_h);
die $usage if (!$opt_H || !$opt_c || !$opt_w || $opt_h || !$opt_i || !$opt_m);
$hostname = $opt_H;
$class = $opt_m;
$warn = $opt_w;
$crit = $opt_c;
$int  = $opt_i;
$community = $opt_C || "public"; undef $opt_C; #use twice to remove Perl warning
if($opt_d) {    
  print "Target hostname: $hostname\n";
  print "SNMPv2 community: $community\n";
  print "Warning level: $warn\n";
  print "Critical level: $crit\n";
  print "Interface: $opt_i\n";
  print "Class map: $opt_m\n";
}

#-------------------------------------------------------------------------------
# Generate temporary file name
#-------------------------------------------------------------------------------
$fname = $opt_i;
$fname =~ s/:/-/g;
$fname =~ s/\//-/g;
$fname =~ s/\./-/g;
$fname = $tmp . "/check_cisco_qos." . $hostname . "." . $fname . "." . $class;
if ( $opt_d ) {
  print "Using temporary file: $fname\n";
}

#-------------------------------------------------------------------------------
# Get last values, if any
#-------------------------------------------------------------------------------
$lastDrop = "0";
$lastPost = "0";
if ( open FILE, "<$fname" ) {
  my @last = <FILE>;
  foreach $i (@last) {
    my @line = split (/=/, $i);
    if ( $line[0] eq "lastDrop" ) {
      $lastDrop = $line[1];
      if ( $opt_d ) {
        print "lastDrop=$lastDrop\n";
      }
    }
    if ( $line[0] eq "lastPost" ) {
      $lastPost = $line[1];
      if ( $opt_d ) {
        print "lastPost=$lastPost\n";
      }
    }
    if ( $line[0] eq "lastEpoch" ) {
      $lastEpoch = $line[1];
      if ( $opt_d ) {
        print "lastEpoch=$lastEpoch\n";
      }
    }
  }
  close FILE;
}
                
#-------------------------------------------------------------------------------
# Open an SNMPv2 session with the router
#-------------------------------------------------------------------------------
my ($session, $error) = Net::SNMP->session(
        -version     => 'snmpv2c',
        -nonblocking => 1,      
        -timeout     => 2,      
        -hostname    => $hostname,
        -community   => $community
);

if (!defined($session)) {               
  printf("ERROR: %s.\n", $error);
  exit (-1);
}

#-------------------------------------------------------------------------------
# Retrieve QoS interfaces
#-------------------------------------------------------------------------------
$base_oid = $ifIndex_oid;
$result = $session->get_bulk_request(
        -callback       => [\&get_bulk, {}],
        -maxrepetitions => 20,
        -varbindlist => [$base_oid]
);  
if (!defined($result)) {
  printf("ERROR: %s.\n", $session->error);
  $session->close;
  exit (-1);
}   
snmp_dispatcher();
undef $result;

if ($ifCount == 0 ) {
  print "QOS: Sorry, QoS is not configured on any interface: ERROR\n";
  exit 3;
}

#-------------------------------------------------------------------------------
# Retrieve QoS class names
#-------------------------------------------------------------------------------
$base_oid = $class_name_oid;
$result = $session->get_bulk_request(
        -callback       => [\&get_bulk, {}],
        -maxrepetitions => 20,
        -varbindlist => [$base_oid]
);
if (!defined($result)) {
  printf("ERROR: %s.\n", $session->error);
  $session->close;
  exit (-1);
}
snmp_dispatcher();
undef $result;

#-------------------------------------------------------------------------------
# Retrieve QoS policy names
#-------------------------------------------------------------------------------
$base_oid = $policy_name_oid;
$result = $session->get_bulk_request(
        -callback       => [\&get_bulk, {}],
        -maxrepetitions => 20,
        -varbindlist => [$base_oid]
);
if (!defined($result)) {
  printf("ERROR: %s.\n", $session->error);
  $session->close;
  exit (-1);
}
snmp_dispatcher();
undef $result;


#-------------------------------------------------------------------------------
# Retrieve QoS config index
#-------------------------------------------------------------------------------
$base_oid = $config_index_oid;
$result = $session->get_bulk_request(
        -callback       => [\&get_bulk, {}],
        -maxrepetitions => 20,
        -varbindlist => [$base_oid]
);
if (!defined($result)) {
  printf("ERROR: %s.\n", $session->error);
  $session->close;
  exit (-1);
}
snmp_dispatcher();
undef $result;

#-------------------------------------------------------------------------------
# Now let's check our QOS config
#-------------------------------------------------------------------------------
get_config();

#-------------------------------------------------------------------------------
# Evaluate results
#-------------------------------------------------------------------------------

if ($lastEpoch) {
  $checkInterval = $epoch - $lastEpoch;
} else {
  $checkInterval = 300;
}

$state = 3;
if ( $opt_i eq "ALL" ) {
  if ( $opt_m eq "ALL" ) {
    #---------------------------------------------------------------------------
    # Check for all interfaces and all classes
    #---------------------------------------------------------------------------
    $dropCount = 0;
    $postCount = 0;
    # Loop on interfaces
    foreach $i ( keys %qos ) {
      # Loop on classes
      foreach $j ( keys %{$qos{$i}{"class"}} ) {
        # Sum up post and drop counters
        $dropCount = $dropCount + $qos{$i}{class}{$j}{drop};
        $postCount = $postCount + $qos{$i}{class}{$j}{post};
      }
    }
    # Calculate average bit rate (requires last drop & last post counters!!)
    if ($lastPost>0) {
      $postRate = sprintf( "%.0f", ($postCount-$lastPost)/$checkInterval );
      if ( $postRate < 0 ) {
	$postRate = sprintf( "%.0f", ($postCount + 34359738368 - $lastPost)/$checkInterval );
      }
    } else {
      $postRate = 0;
    }
    if ($lastDrop>0) {
      $dropRate = sprintf( "%.0f", ($dropCount-$lastDrop)/$checkInterval );
      if ( $dropRate < 0 ) {
        $dropRate = sprintf( "%.0f", ($dropCount + 34359738368 - $lastDrop)/$checkInterval );
      }
    } else {
      $dropRate = 0;
    }
    if ( $dropRate >= $crit ) {
      $short = "QOS: Total drop rate ($dropRate bits/s) is above critical threshold ($crit bits/s): CRITICAL";
      $perf  = sprintf "Sent=%sBits/s;Dropped=%sBits/s",$postRate,$dropRate;
      $state   = 2;
    } elsif ( $dropRate >= $warn ) {
      $short = "QOS: Total drop rate ($dropRate bits/s) is above warning threshold ($warn bits/s): WARNING";
      $perf  = sprintf "Sent=%sBits/s;Dropped=%sBits/s",$postCount,$dropCount;
      $state   = 1;
    } else {
      $short = "QOS: Total drop rate ($dropRate bits/s) is below warning threshold ($warn bits/s): OK";
      $perf  = sprintf "Sent=%sBits/s;Dropped=%sBits/s",$postRate,$dropRate;
      $state   = 0;
    }
    $perf  = sprintf "Sent=%s Dropped=%s;%s;%s",$postRate,$dropRate,$warn,$crit;
  } else {
    #---------------------------------------------------------------------------
    # Check for all interfaces and one class
    #---------------------------------------------------------------------------
    $dropCount    = 0;
    $postCount    = 0;
    $temp         = 0;
    # Loop on interfaces
    foreach $i ( keys %qos ) {
      if ( defined $qos{$i}{class}{$opt_m} ) {
        $temp++;
        $dropCount    = $dropCount    + $qos{$i}{class}{$opt_m}{drop};
	$postCount    = $postCount    + $qos{$i}{class}{$opt_m}{post};
      }
    }
    # Calculate average bit rate (requires last drop & last post counters!!)
    if ($lastPost>0) {
      $postRate = sprintf( "%.0f", ($postCount-$lastPost)/$checkInterval );
      if ( $postRate < 0 ) {
        $postRate = sprintf( "%.0f", ($postCount + 34359738368 - $lastPost)/$checkInterval );
      }
    } else {
      $postRate = 0;
    }
    if ($lastDrop>0) {
      $dropRate = sprintf( "%.0f", ($dropCount-$lastDrop)/$checkInterval );
      if ( $dropRate < 0 ) {
        $dropRate = sprintf( "%.0f", ($dropCount + 34359738368 - $lastDrop)/$checkInterval );
      }
    } else {
      $dropRate = 0;
    }
    if ( $temp == 0 ) {
      print "QOS: QoS class $opt_m is not configured on any interface: UNKNOWN\n";
      exit 3;
    }
    $perf  = sprintf "Sent=%sBits/s;Dropped=%sBits/s",$postRate,$dropRate;
    $perf  = sprintf "Sent=%s Dropped=%s;%s;%s",$postRate,$dropRate,$warn,$crit;
    if ( $dropRate >= $crit ) {
      $short = "QOS: Total drop rate for class $opt_m ($dropRate bits/s) is above critical threshold ($crit bits/s): CRITICAL";
      $state = 2;
    } elsif ( $dropRate >= $warn ) {
      $short = "QOS: Total drop rate for class $opt_m ($dropRate bits/s) is above warning threshold ($warn bits/s): WARNING";
      $state = 1;
    } else {
      $short = "QOS: Total drop rate for class $opt_m ($dropRate bits/s) is below warning threshold ($warn bits/s): OK";
      $state = 0;
    }
  }
} else {
  if ( !defined $qos{$opt_i} ) {
    print "QOS: QoS is not configured on interface $opt_i: UNKNOWN\n";
    exit 3;
  }
  if ( $opt_m eq "ALL" ) {
    #---------------------------------------------------------------------------
    # Check for all classes on one interface
    #---------------------------------------------------------------------------
    $dropCount    = 0;
    $postCount    = 0;
    foreach $i ( keys %{$qos{$opt_i}{"class"}} ) {
	$dropCount    = $dropCount    + $qos{$opt_i}{class}{$i}{drop};
	$postCount    = $postCount    + $qos{$opt_i}{class}{$i}{post};
    }
    # Calculate average bit rate (requires last drop & last post counters!!)
    if ($lastPost>0) {
      $postRate = sprintf( "%.0f", ($postCount-$lastPost)/$checkInterval );
      if ( $postRate < 0 ) {
        $postRate = sprintf( "%.0f", ($postCount + 34359738368 - $lastPost)/$checkInterval );
      }
    } else {
      $postRate = 0;
    }
    if ($lastDrop>0) {
      $dropRate = sprintf( "%.0f", ($dropCount-$lastDrop)/$checkInterval );
      if ( $dropRate < 0 ) {
        $dropRate = sprintf( "%.0f", ($dropCount + 34359738368 - $lastDrop)/$checkInterval );
      }
    } else {
      $dropRate = 0;
    }
    $perf  = sprintf "Sent=%sBits/s;Dropped=%sBits/s",$postRate,$dropRate;
    $perf  = sprintf "Sent=%s Dropped=%s;%s;%s",$postRate,$dropRate,$warn,$crit;
    if ( $dropRate >= $crit ) {
      $short = "QOS: Total drop rate on $int ($dropRate bits/s) is above critical threshold ($crit bits/s): CRITICAL";
      $state = 2;
    } elsif ( $dropRate >= $warn ) {
      $short = "QOS: Total drop rate on $int ($dropRate bits/s) is above warning threshold ($warn bits/s): WARNING";
      $state = 1;
    } else {
      $short = "QOS: Total drop rate on $int ($dropRate bits/s) is below warning threshold ($warn bits/s): OK";
      $state = 0;
    }
  } else {
    #---------------------------------------------------------------------------
    # Check for one class on one interface
    #---------------------------------------------------------------------------
    if ( !defined $qos{$opt_i}{class}{$opt_m} ) {
      print "QOS: QoS class $opt_m is not configured on interface $opt_i: UNKNOWN\n";
      exit 3;
    }
    $dropCount    = $qos{$opt_i}{class}{$opt_m}{drop};
    $postCount    = $qos{$opt_i}{class}{$opt_m}{post};
    # Calculate average bit rate (requires last drop & last post counters!!)
    if ($lastPost>0) {
      $postRate = sprintf( "%.0f", ($postCount-$lastPost)/$checkInterval );
      if ( $postRate < 0 ) {
        $postRate = sprintf( "%.0f", ($postCount + 34359738368 - $lastPost)/$checkInterval );
      }
    } else {
      $postRate = 0;
    }
    if ($lastDrop>0) {
      $dropRate = sprintf( "%.0f", ($dropCount-$lastDrop)/$checkInterval );
      if ( $dropRate < 0 ) {
        $dropRate = sprintf( "%.0f", ($dropCount + 34359738368 - $lastDrop)/$checkInterval );
      }
    } else {
      $dropRate = 0;
    }
    $perf  = sprintf "Sent=%sBits/s;Dropped=%sBits/s",$postRate,$dropRate;
    $perf  = sprintf "Sent=%s Dropped=%s;%s;%s",$postRate,$dropRate,$warn,$crit;
    if ( $dropRate >= $crit ) {
      $short = "QOS: Drop rate for $opt_m on $opt_i ($dropRate bits/s) is above critical threshold ($crit bits/s): CRITICAL";
      $state = 2;
    } elsif ( $dropRate >= $warn ) {
      $short = "QOS: Drop rate for $opt_m on $opt_i ($dropRate bits/s) is above warning threshold ($warn bits/s): WARNING";
      $state = 1;
    } else {
      $short = "QOS: Drop rate for $opt_m on $opt_i ($dropRate bits/s) is below warning threshold ($warn bits/s): OK";
      $state = 0;
    }
  }
}

# Save current sent and drop counters
if ( open FILE, ">$fname" ) {
  print FILE "lastDrop=$dropCount\nlastPost=$postCount\nlastEpoch=$epoch\n";
  close FILE;
}

print $short . " | " . $perf . "\n";
exit $state;

################################################################################
###                               SUBS SECTION                               ###
################################################################################

#-------------------------------------------------------------------------------
# Browse QoS MIB and "resolve" dependencies
#-------------------------------------------------------------------------------
sub get_config
{
  $epoch = time;
  foreach my $class_id (sort keys %qos_classes) {
    $class_name = $qos_classes{$class_id};
    foreach $i (sort keys %qos_config) {
      $qos_config_value = $qos_config{$i};
      @qos_index = split /\./,$i;
      if ($qos_config_value == $class_id ) {
        foreach $ifIndex (sort keys %qos_interfaces) {
          if ($ifIndex eq $qos_index[0]) {
            $tmp   = $ifIndex . "." . $ifIndex;
            $policyIndex  = $qos_config{$tmp};
            $policyName   = $qos_policies{$policyIndex};
            $ifPolicy = $qos_interfaces{$ifIndex};
	    $post_oid = $cbQosCMPostPolicyByte.".".$i;
            $drop_oid = $cbQosCMDropByte.".".$i;
            $if_oid   = $ifName_oid.".".$ifPolicy;
            $bw_oid   = $ifSpeed_oid.".".$ifPolicy;
            my @oids = (
              $post_oid,
              $drop_oid,
              $if_oid,
              $bw_oid
            );
            $result = $session->get_request(
                      -callback       => [\&get_oids, {}],
                      -varbindlist    => \@oids
                    );
            if (!defined($result)) {
              printf("ERROR: %s.\n", $session->error);
              $session->close;
              exit (-1);
            }
            snmp_dispatcher();
            undef $result;
          }
        }
      }
    }
  }
}

#-------------------------------------------------------------------------------
# Handle get_requests
#-------------------------------------------------------------------------------
sub get_oids
{
  my ($session, $table) = @_;
  my %snmpGet;
  if (!defined($session->var_bind_list)) {
    printf("ERROR: %s\n", $session->error);
  } else {
    foreach my $oid (keys(%{$session->var_bind_list})) {
      $snmpGet{$oid} = $session->var_bind_list->{$oid};
    } 
  } 
  if($opt_d) {
    print "OIDs Found:\n";
    foreach $k (sort keys %snmpGet) {
      print "$k => $snmpGet{$k}\n"; 
    }
    print "\n";
  }
  my $post    = $snmpGet{$post_oid};
  my $drop    = $snmpGet{$drop_oid};
  my $ifName  = $snmpGet{$if_oid};
  my $ifSpeed = $snmpGet{$bw_oid};

  # Convert post and drop values from Bytes to Bits
  $post       = $post * 8;
  $drop       = $drop * 8;

  # Let's fill the QoS hash in
  $qos{$ifName}{"speed"}                      = $ifSpeed;
  $qos{$ifName}{"policy"}                     = $policyName;
  $qos{$ifName}{"class"}{$class_name}{"post"} = $post;
  $qos{$ifName}{"class"}{$class_name}{"drop"} = $drop;

  # Debug output
  if ($opt_d) {
   $temp = sprintf "Interface %-10s: Speed %-9s Policy %-9s Class %-20s post=%-12sbits drop=%-12sbits\n",
   $ifName,$ifSpeed,$policyName,$class_name,$post,$drop;
   print $temp;
  }
}

#-------------------------------------------------------------------------------
# Handle bulk_requests
#-------------------------------------------------------------------------------
sub get_bulk
{
  my ($session, $table) = @_;
  if (!defined($session->var_bind_list)) {
    printf("ERROR: %s\n", $session->error);
    exit 3;
  }
  #---------------------------------------------------------------
  # Loop through each of the OIDs in the response and assign
  # the key/value pairs to the anonymous hash that is passed
  # to the callback.  Make sure that we are still in the table
  # before assigning the key/values.
  #---------------------------------------------------------------
  my $next;
  foreach my $oid (oid_lex_sort(keys(%{$session->var_bind_list}))) {
    if (!oid_base_match($base_oid, $oid)) {
      $next = undef;
      last;
    }
    $next = $oid;
    $table->{$oid} = $session->var_bind_list->{$oid};
  }
  #---------------------------------------------------------------
  # If $next is defined we need to send another request
  # to get more of the table.
  #---------------------------------------------------------------
  if (defined($next)) {
    $result = $session->get_bulk_request(
              -callback       => [\&get_bulk, $table],
              -maxrepetitions => 10,
              -varbindlist    => [$next]
              );
    if (!defined($result)) {
      printf("ERROR: %s\n", $session->error);
      exit 3;
    }
  } else {
    #-------------------------------------------------------
    # We are no longer in the table, so print the results.
    #-------------------------------------------------------
    foreach my $oid (oid_lex_sort(keys(%{$table}))) {
      #-----------------------------------------------------
      # QoS Class names
      #-----------------------------------------------------
      if ($oid =~ /^$class_name_oid.(\d+)$/) {
	my $index = $1;
	my $value = $table->{$oid};
        if($opt_d) {
          print "Got qos-class index $1 for $value\n";
        }
	$qos_classes{$index} = "$value";
      }
      #-----------------------------------------------------
      # QoS Policy names
      #-----------------------------------------------------
      if ($oid =~ /^$policy_name_oid.(\d+)$/) {
        my $index = $1;
        my $value = $table->{$oid};
        if($opt_d) {
          print "Got qos-policy index $1 for $value\n";
        }
        $qos_policies{$index} = "$value";
      }
      #-----------------------------------------------------
      # QoS Config indexes
      #-----------------------------------------------------
      if ($oid =~ /^$config_index_oid.(\d+\.\d+.)$/) {
        my $index = $1;
        my $value = $table->{$oid};
        if($opt_d) {
          print "Got qos-config index $1 for $value\n";
        }
        $qos_config{$index} = "$value";
      }
      #-----------------------------------------------------
      # QoS Config interfaces
      #-----------------------------------------------------
      if ($oid =~ /^$ifIndex_oid.(\d+)$/) {
        $ifCount++;
        my $index = $1;
        my $value = $table->{$oid};
        if($opt_d) {
          print "Got qos-interface index $index with ifIndex $value\n";
        }
        $qos_interfaces{$index} = "$value";
      }
    }
  }
}
