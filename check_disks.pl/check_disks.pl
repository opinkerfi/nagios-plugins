#!/usr/bin/perl

# nagios: -epn

=head1 PLUGIN

    check_disk.pl : check disks on Unix servers

=head1 ENVIRONNEMENT

    Linux


=head1 CONTEXT

    Projet : Offre Standard Nagios
    Equipe : Sigma/DTE/ISR
    Copyright (c) 2005 Groupe Sigma Informatique. Tous droits reserves.

=head1 SYNOPSIS

    ./check_disk.pl [-H <host>] [-w <num>] [-c <num>] [-u <user>] [-p <path>] 
                    [-i <dev>] [-f <fs>] [-h] [-C <file>]
     -h | --help     : Display this help
     -w | --warning  : % free space to send warning alert (default 10)
     -c | --critical : % free space to send critical alert (default 5)
     -H | --host     : host you want to check by NRPE (default localhost)
     -u | --user     : user for NRPE connection (default nagios)
     -i | --ignore   : Filesystem you want to ignore
                        format : <name>,<name>,<name>....
     -r /pattern/    : include all filesystems matching this regexp
     -R /pattern/    : exclude all filesystems matching this regexp
     -f | --filesystem : filesystems or device you have to check (default all)
                         format : <name>:warn[U]:crit[U],<name>:warn:crit,...
                         with U = {K,M,G,T} or none for %
     -C | --conf     : specify a configuration file for filesystems threshold 
                       definitions
     -v | --verbose  : plugin output contain all FS(default : output shows 
                       only warning or critical FS).
     --srvperf dir   : Save datas external files placed on this directory 
     --html          : Add <br> in plugin output to improve the Web interface 
                       output. 

    -w and -c options allow you to ajust default threshold of all checked fs. 
Theses values can be overwritten with -C option by specifying a configuration 
file. perldoc ckech_disk.pl for more details.
    If you want to use the NRPE connexion and check remote hosts, you must create 
a connection without password between your nagios server and the checked host 
(key exchange).


=head1 EXAMPLE

=head2 No config file for FS :

    All FS will have the same threshold :

    not verbose mode : 
    ./check_disk.pl -w 20 -c 10
    DISKS OK

    verbose mode : 
    ./check_disk.pl -w 20 -c 10 -v
    DISK OK [/dev/shm 125.1M (100% free)] [/usr 1.1G (56% free)] [/ 357.2M (84%
free)] [/var 1.5G (73% free)] [/tmp 989.7M (96% free)] [/home 1.8G (90% free)]

    ignore some FS : 
    ./check_disk.pl -i /dev/shm,/tmp,/home -v
    DISK OK [/usr 1.1G (56% free)] [/ 357.2M (84% free)] [/var 1.5G (73% free)]

    Specify different threshold :
    ./check_disk.pl -w 20 -c 10 -f /usr:30:25 -i /dev/shm,/tmp,/home -v

    Specify another unit (K kilo, M Mega, G Giga, T Tera) : 
    ./check_disk.pl -w 20 -c 10 -f /usr:400M:300M -i /dev/shm,/tmp,/home 


=head2 With a FS config file :

    Syntaxe (check_disk.cfg): 

    #FS     WARN    CRIT
    /       400M    300M
    /home   20      15
    /var    1G      500M

    FS threshold are read in this configuration file. the -f option will 
not be used.

    ./check_disk.pl -C check_disk.cfg -i /dev/shm,/tmp,/home
    DISK WARNING [/ 357.2M (84% free)]

=head1 HISTORY

    $Log: check_disk.pl,v $

    Revision 1.9 2010/02/27 00:55:00   palli@ok.is
    o Changed UNKNOWN return code from -1 to 3
    o Modified to use check_nrpe instead of ssh
    o Modified to check output of $cmd and check for errors
    o Always output perf_data with the regular output for nagios's sake
 
    Revision 1.8  2006/05/17 16:05:00  jflamand
    o bug fix

    Revision 1.6  2006/05/17 13:07:07  ebollengier
     o ajout include/exclude (-r/-R)

    Revision 1.5  2006/05/17 12:21:29  ebollengier
     o passage -H localhost par defaut

    Revision 1.4  2006/05/17 12:01:55  jflamand
    o bug fix

    Revision 1.3  2006/05/17 09:53:33  jflamand
    o taux warn et crit en % ou octets K M G T

    Revision 1.2  2006/05/10 16:38:58  ebollengier
     o ajout mode srvperf pour serveur nagios seulement

    Revision 1.1  2006/05/10 13:52:08  jflamand
    o creation plugin


=cut

use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use strict;

my ($opt_c, $opt_w, $opt_h, $opt_i,$opt_f,$opt_s,$opt_u,$opt_H,$opt_C,$opt_v,
    $opt_html, $opt_srvperf, $opt_r, $opt_R);

$ENV{'PATH'} = "/usr/lib/nagios/plugins:/usr/lib64/nagios/plugins:/usr/local/libexec:/usr/libexec:/usr/local/nagios/libexec";

$opt_u = "nagios";  # Utilisateur pour connexion nrpe
$opt_i = "";
$opt_w = "10";      # Valeur par defaut de warning
$opt_c = "5";       # Valeur par defaut de critical
$opt_H = "localhost";
$opt_R = q/^$/;
$opt_r = "";

my $exclude_re = "(^//|^none)";

my %alldisks; # Tous les disques trouves avec la commande df
my %checkdisks; # seulement les disque a verifier
my $cmd = "/bin/df -k";
my $output ;
my $retour = 'OK';
my %EXIT_CODES = (
        'UNKNOWN'       => 3,
        'OK'            => 0,
        'WARNING'       => 1,
        'CRITICAL'      => 2
);


################################################################################
# Recuperation des Options de ligne de commande

GetOptions(
        "h"   => \$opt_h,   "help"                => \$opt_h,
        "H=s" => \$opt_H,   "host=s"              => \$opt_H,
        "w=s" => \$opt_w,   "warning=s"           => \$opt_w,
        "c=s" => \$opt_c,   "critical=s"          => \$opt_c,
        "u=s" => \$opt_u,   "user=s"              => \$opt_u,
        "i=s" => \$opt_i,   "ignore=s"            => \$opt_i,
        "f=s" => \$opt_f,   "filesystem=s"        => \$opt_f,
        "C=s" => \$opt_C,   "conf=s"              => \$opt_C,
        "v"   => \$opt_v,   "verbose"             => \$opt_v,
        "r=s" => \$opt_r,   "R=s"                 => \$opt_R,
        "html"   => \$opt_html,
        "srvperf=s" => \$opt_srvperf,
) ||  pod2usage() ;

if ($opt_h) {
    pod2usage(-verbose=>1);
    exit $EXIT_CODES{'OK'};
}
if(!$opt_H) {
    pod2usage();
    exit $EXIT_CODES{'UNKNOWN'};
}

my $args;

# Lancement de la commande df et recuperation dans un HASH de 
# tous les disques
#
# %disks{'nom_disque'}
#           ->{used} : espace occupe en octets
#           ->{free} : espace libre en octets
#           ->{pused} : espace occupe en pourcentage
#           ->{pfree} : espace libre en pourcentage
#           ->{warning} : taux warning en % espace libre
#           ->{critical} : taux critique en % espace libre
#

#Si on est en local inutile de faire du nrpe
if($opt_H ne "localhost" and $opt_H ne "127.0.0.1") {
    #$cmd = "ssh $opt_u\@$opt_H '$cmd'";
    $cmd = "check_nrpe -H $opt_H -c get_disks";
    #$cmd = "cat /tmp/df";
    #print "$cmd";
}

# Envoi commande et renseignement Hashage %disks
my @output = `$cmd`;
my $ret = $?;

if ($ret == -1) {
	print "Could not find " . (split(' ', $cmd))[0] . "\n";
	exit $EXIT_CODES{'UNKNOWN'};
}

$ret >>= 8;
# 2010/02/25 palli@ok.is : Check if $cmd ran successfully
if ($ret > 0) {
   print "Failed to execute $cmd: " . join("\n", @output) . "\n";
   exit $EXIT_CODES{'UNKNOWN'} ;
}
#
#/dev/hda1               459143     68879    365767  16% /
#tmpfs                   128056         0    128056   0% /dev/shm
#/dev/mapper/datavg-home
#                       2097084    202824   1894260  10% /home
#/dev/mapper/datavg-tmp
#                       1048540     35132   1013408   4% /tmp
#/dev/mapper/datavg-var
#                       2097084    550476   1546608  27% /var
#/dev/mapper/datavg-usr
#                       2097084    911280   1185804  44% /usr
#

foreach my $l (@output) {
    if($l =~ /(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\%\s+([\/\w\d\.-]+)$/) {
        next if ($l =~ m/$opt_R/);
        next if ($l !~ m/$opt_r/);
        next if ($l =~ m/$exclude_re/);
        my ($s,$u,$f,$pu,$d) = ($1,$2,$3,$4,$5);
        $alldisks{$d}->{pused} = $pu;
        $alldisks{$d}->{pfree} = 100-$pu;
        $alldisks{$d}->{somme} = $s*1024;
        $alldisks{$d}->{used} = $u*1024;
        $alldisks{$d}->{free} = $f*1024;

        # par defaut on prend les taux Warn et Crit specifies
        updateRates($d,$opt_w,$opt_c,$alldisks{$d}->{somme});
    }
# This is the output of df.exe on Windows
#C:\    9097126      6094081      3003045    67% argon-c (ntfs)
    else {
	if ($l =~ /(\w)\:\\\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\%\s+(.*)$/) {
        next if ($l =~ m/$opt_R/);
        next if ($l !~ m/$opt_r/);
        next if ($l =~ m/$exclude_re/);
        my ($d,$s,$u,$f,$pu) = ("/$1",$2,$3,$4,$5);
        $alldisks{$d}->{pused} = $pu;
        $alldisks{$d}->{pfree} = 100-$pu;
        $alldisks{$d}->{somme} = $s*1024;
        $alldisks{$d}->{used} = $u*1024;
        $alldisks{$d}->{free} = $f*1024;
	#print $l;
	#print "pused = $pu\n";
	#print "pfree = 100-$pu\n";
	#print "somme = $s\n";
	#print "used = $u\n";
	#print "free = $f\n";
	#print "name = $d\n";
	#exit 3;

        # par defaut on prend les taux Warn et Crit specifies
        updateRates($d,$opt_w,$opt_c,$alldisks{$d}->{somme});
	}
    }
}

# 2010/02/25 palli@ok.is : Fail if df did not in fact return any disks
my $len = scalar(keys %alldisks);
if ( scalar(keys %alldisks) < 1) {
	print "unable to discover any disks. Output from df command: @output\n";
	exit $EXIT_CODES{'UNKNOWN'} ;
}


use Data::Dumper;

# Lecture des arguments WARN et CRIT en renseignement dans le HASH
# des disque a verifier.
# %checkdisks{'nom_disque'}
#           ->{used} : espace occupe en octets
#           ->{free} : espace libre en octets
#           ->{pused} : espace occupe en pourcentage
#           ->{pfree} : espace libre en pourcentage
#           ->{warning} : taux warning en % espace libre
#           ->{critical} : taux critique en % espace libre
#


# Option -f specifie
if($opt_f) {
    my @fs = split(',',$opt_f);
    foreach my $f (@fs) {
        # <nom_fs> ou <nom_fs,warn,crit>
        if($f =~ /^[\/\w\d]+$/) {
            if(defined($alldisks{$f})) {
                $checkdisks{$f}=$alldisks{$f};
            }
        } elsif ($f =~ /([\/\w\d]+)\:(\w+)\:(\w+)/) {
            if(defined($alldisks{$1})) {
                $checkdisks{$1}=$alldisks{$1};
                updateRates($1,$2,$3,$checkdisks{$1}->{somme});
            }
        } else {
            print "option -f invalide\n";
            pod2usage();
            exit $EXIT_CODES{'UNKNOWN'};
        }
    }
}
# sinon fichier de conf specifie
elsif ($opt_C) {
    open(FIC,"<$opt_C") or die "$!";
    foreach my $l (<FIC>) {
        if($l =~ /^([\/\w\d]+)\s+(\w+)\s+(\w+)$/) {
            my ($d,$w,$c)=($1,$2,$3);
            if(defined($alldisks{$d})) {
                $checkdisks{$d}=$alldisks{$d};
                updateRates($d,$w,$c,$checkdisks{$d}->{somme});
            }
        }
    }
    close(FIC);
} 

%checkdisks= (%alldisks, %checkdisks);

# on enleve les FS a ignorer
if($opt_i) {
    my @fs = split(',',$opt_i);
    foreach my $f (@fs, "/cdrom", "/mnt/cdrom") {
        if(defined($checkdisks{$f})) {
            delete $checkdisks{$f};
        }
    }
}

my $cmp_warn=0;     # compteur de disques en avertissement
my $cmp_crit=0;     # compteur de disques critiques
my $perf_data="";   # Donnees de perf

my $critical_disks = "";
my $warning_disks = "";
my $ok_disks = "";

# Tests Warn et Crit de tous les fs et creation de l'output
foreach my $f (keys %checkdisks) {
	if ($opt_v) { $output .= "\n"; }
    if($checkdisks{$f}->{pfree} < $checkdisks{$f}->{critical}) {
	$critical_disks .= " " . $f ;	
        $cmp_crit++;
    } 
    elsif ($checkdisks{$f}->{pfree} < $checkdisks{$f}->{warning}) {
	$warning_disks .= " " . $f ;	
        $cmp_warn++;
    } else {
	$ok_disks .= " " . $f ;	
    }
        $output .= "[$f " . byte2human($checkdisks{$f}->{free}) .
                          " (" . $checkdisks{$f}->{pfree} . '% free) ;' .
			   "warning=" . $checkdisks{$f}->{warning} . "% " .
			   "critical=" . $checkdisks{$f}->{critical} . "% " .
			'] ' ;
        $output .= "<br>" if ($opt_html);
	    #$output .= "\n";
    
    # Donnees de Perfs
    my $perfwarn=$alldisks{$f}->{somme}*((100-$checkdisks{$f}->{warning})/100);
    $perfwarn = sprintf("%0.f",$perfwarn);
    my $perfcrit=$alldisks{$f}->{somme}*((100-$checkdisks{$f}->{critical})/100);
    $perfcrit = sprintf("%0.f",$perfcrit);

    $perf_data.="$f=$checkdisks{$f}->{used}B;".
               "$perfwarn;".
               "$perfcrit;".
               "0;".
               "$checkdisks{$f}->{somme} ";
}

if($cmp_crit > 0) {
    $retour='CRITICAL';
} elsif ($cmp_warn > 0) {
    $retour='WARNING';
} else {
    $retour='OK';
}

#Enregistrement des donnees de perf dans un fichier separe pour la generation
# des graphs
#time|machine|service|output|perf
if (-d $opt_srvperf) {
    eval {
         require Mayday;
         require Mayday::Config;
         my $cfg = new Mayday::Config(version => $Mayday::nagios_version,
                                     cgi_file => $Mayday::nagios_cgi_cfg) ;

         die "Can't read nagios configuration" unless $cfg ;

         my $host = $cfg->get_host_by_address($opt_H) || $opt_H;

         open(FP, ">>$opt_srvperf/$host.perfdata") ;
         print FP time(),"|$host|disk|DISK $retour $output|$perf_data\n" ;
         close(FP) ;
    }
}

# Sortie du plugin : sans donnees de perfs qui sont stockes 
# dans d'autres fichiers
print "DISK $retour $critical_disks $warning_disks ...  $output | $perf_data\n";
exit $EXIT_CODES{$retour};

##########################################################################
# FONCTIONS

# value : valeur a convertir
# unit : unite : K M G ou T
# max : valeur max en octets

sub byte2percent {
    my ($value,$unit,$max) = @_;
    my $return;
    #Kilo Mega Giga Tera 
    my @units = qw (K M G T);
    if(!grep {$_ eq $unit} @units) {
        print "Erreur : unite inconnue ($unit)\n";
        return 0;
    }
    if($unit eq 'K') {
        $return = sprintf("%d",100*(1024*$value)/$max);
    } elsif ($unit eq 'M') {
        $return = sprintf("%d",100*(1024*1024*$value)/$max);
    } elsif ($unit eq 'G') {
        $return = sprintf("%d",100*(1024*1024*1024*$value)/$max);
    } elsif ($unit eq 'T') {
        $return = sprintf("%d",100*(1024*1024*1024*1024*$value)/$max);
    }
    #Borne a 100 %
    if($return > 100) { 
        return 100;
    }
    return $return;
}

sub byte2human {
    my ($value) = @_;
    my $i=0;

    my @units = qw/B K M G T/;

    while (($value / 1024) >= 1) {
	$value /= 1024;
	$i++;
    }
    return sprintf('%.1f%s',$value, $units[$i]);
}

# permet de mettre a jour les taux warn et crit en prenant en 
# compte l'unite (K M G T)
sub updateRates {
    my ($disk,$w,$c,$max) = @_;

    if($w =~ m/^(\d+)(\D)/) {
	$alldisks{$disk}->{'warning'}=
	    byte2percent($1,$2,$alldisks{$disk}->{somme});	
    } else {
        $alldisks{$disk}->{'warning'}=$w;
    }
    if($c =~ /^(\d+)(\D)/) {
        $alldisks{$disk}->{'critical'}=
	    byte2percent($1,$2,$alldisks{$disk}->{somme});
    } else {
        $alldisks{$disk}->{'critical'}=$c;
    }
}
