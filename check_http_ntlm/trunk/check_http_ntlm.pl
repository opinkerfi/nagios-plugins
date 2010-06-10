#!/usr/bin/perl

#       02/Feb/10                       nagios@sanxiago.com
#  check_http page for IIS servers with ntlm authentication
#
# this check receives a URL as a parameter, logins to the IIS server
# using the curl binary, then it parses the output of the command
# and captures the response code. Timeout pass and user values are currently hardcoded
# script currently only has handlers for some response codes, but a switch was used to 
# add more in an easy way. Response code is found with regexp /HTTP\/1\.1 ([0-9]{3}) .*/

use Switch;
use Time::HiRes;

if (@ARGV < 3) {
	print "Usage $0 <username> <password> <uri>\n";
	exit 2;
}

$uri=$ARGV[2];          # URL OF THE PAGE WE WANT TO CHEK
$user=$ARGV[0];       # User
$pass=$ARGV[1]; # Password
$timeout=30;            # Timeout in seconds

$start = Time::HiRes::time();
run_command("curl -u $user:$pass --ntlm  --stderr /dev/null $uri  -i ");
$time = sprintf("%.2f",Time::HiRes::time()-$start);

switch ($http_code){
	case 200 {print $time."s $http_code OK | \"response_time\"=$time" . "s\n"; exit(0);}
	case 302 {print $time."s $http_code PAGE MOVED | \"response_time\"=$time" . "s\n"; exit(1);}
	case 403 {print $time."s $http_code Forbidden | \"response_time\"=$time" . "s\n"; exit(1);}
	case 404 {print $time."s $http_code PAGE NOT FOUND | \"response_time\"=$time" . "s\n"; exit(2);}
	case 500 {print $time."s $http_code SERVER ERROR | \"response_time\"=$time" . "s\n"; exit(2);}
	case 401 {print $time."s $http_code UNAUTHORIZED | \"response_time\"=$time" . "s\n"; exit(1);}
	else     {print $time."s $http_code ERROR $http_code $output | \"response_time\"=$time" . "s\n"; exit(2);}
}

sub run_command {
	$command=shift;
	$command_name=$command;
	$command_name=~ s/\n/\s/;
	$pid = open(PIPE, "$command  |") or die $!;
	eval {
       		$output="";
       		local $SIG{ALRM} = sub { die "TIMEDOUT" };
       		alarm($timeout);
        	while (<PIPE>) {
			print if ($ARGV[3]);
                	if($_=~/HTTP\/1\.1 ([0-9]{3}) .*/ && $authentication_sent){
                        	$http_code=$1;
                	}
                	if($_=~/WWW-Authenticate/){
                        	$authentication_sent=1;
                	}
                	$output=$output.$_;
        	}
        	close(PIPE);
	};
	if ($@) {
    		die $@ unless $@ =~ /TIMEDOUT/;
    		print "TIMEOUT";
    		kill 9, $pid;
    		$? ||= 9;
    		exit(2);
	}
}
