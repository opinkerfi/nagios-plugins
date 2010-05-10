#!/usr/bin/perl 
#
# Copyright 2010, Tomas Edwardsson 
#
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use warnings;
use MIME::Lite;
use MIME::Entity;
use MIME::Base64;

# Some defaults
my $pnp4nagios_perfdata = '/var/lib/pnp4nagios/perfdata';
my $pnp4nagios_phpdir = '/usr/share/nagios/html/pnp4nagios';
my $nagios_cgiurl = "http://nagios/nagios/cgi-bin";
my $pnp4nagios_url = "http://nagios/nagios/pnp4nagios/";
my $from_address = 'nagios@opensource.is';
my $logo = '/usr/share/nagios/html/images/sblogo.png';

if (@ARGV != 8) {
	usage();
}

my ($recipient, $date, $type, $host, $ip, $service, $state, $message) = @ARGV;

my %nagioscmd = (
	service_downtime => 56,
	service_ack => 34,
);

my $rrd = '';
if (-f "$pnp4nagios_perfdata/$host/$service.rrd") {
	my $t = time();
	$rrd = `( cd $pnp4nagios_phpdir;php -r 'parse_str("host=$host&srv=$service&source=1&view=0&end=$t&display=image", \$_GET); include_once("index.php");' )`;
}

my $head = MIME::Entity->build(
	Type		=> 'multipart/related',
	From		=> $from_address,
	To		=> $recipient,
	Subject		=> "Nagios, $state - $host - $service"
);

my $alt = MIME::Entity->build(
	Type		=> 'multipart/alternative'
);

my $txt_content = MIME::Entity->build(
	Type		=> 'text/plain',
	Charset		=> 'UTF-8',
	Encoding	=> 'quoted-printable',
	Data		=> sprintf(<<EO),
Host: $host ($ip)
Service: $service
State: $state
Date: $date
Notification Type: $type
Description: $message
EO
);

my $state_color = '#33FF00';

if ($state eq 'WARNING') {
	$state_color = '#FFFF00';
} elsif ($state eq 'CRITICAL') {
	$state_color = '#F83838';
}


my $ack = '';
if ($state ne 'OK') {
	my $ackurl = sprintf("%s/cmd.cgi?host=%s&service=%s",
		$nagios_cgiurl,
		$host,
		$service);
	$ack = qq{
  <tr>
    <td colspan="1" style="background: black;color: white;font-weight: bold">Service Actions</td>
    <td colspan="1" style="background: white;color: black"><a class="cmd" href="$ackurl?cmd_typ=$nagioscmd{service_ack}">Acknowledge</a> <a class="cmd" href="$ackurl?cmd_typ=$nagioscmd{service_downtime}">Schedule Downtime</a></td>
  </tr>
};
}

my $html_content = MIME::Entity->build(
	Type		=> 'text/html',
	Charset		=> 'UTF-8',
	Encoding	=> 'quoted-printable',
	Data		=> qq{
<head>
<style type="text/css">
th {
	background: black;
	color: white;
	font-weight: bold;
	text-align: left;
	width: 220px;
}
a {
	text-decoration: underline;
	font-weight: bold;
	font-size: 90%;
	color: black;
}
a.cmd {
	padding: 2px;
	margin: 5px 5px 5px 0px;
	border: solid 1px black;
	background: #eee;
	float: right;
}
</style>
</head>
<body>
<table style="background: #ddd;width: 604px">
  <tr>
    <th colspan="2"><img src="cid:sblogo.png"></td>
  </tr>
  <tr>
    <th>Host</td>
    <td style="background: white;color: black"><a style="color: black;text-decoration: underline" href="$nagios_cgiurl/extinfo.cgi?type=1&host=$host">$host ($ip)</a></td>
  </tr>
  <tr>
    <th>Service</td>
    <td style="background: white;color: black"><a style="color: black;text-decoration: underline" href="$nagios_cgiurl/extinfo.cgi?type=2&host=$host&service=$service">$service</a></td>
  </tr>
  <tr>
    <th>State</td>
    <td style="background: $state_color;color: black;font-weight: bold">$state</td>
  </tr>
  <tr>
    <th>Date</td>
    <td style="background: white;color: black">$date</td>
  </tr>
  <tr>
    <th>Type</td>
    <td style="background: white;color: black">$type</td>
  </tr>
$ack
  <tr>
    <th colspan="2">Description</td>
  </tr>
  <tr>
    <td colspan="2" style="background: white;color: black">$message</td>
  </tr>
} . ($rrd ? qq{
  <tr>
    <td style="background: white" colspan="2">
      <a href="$pnp4nagios_url?host=$host&srv=$service"><img border=0 src="cid:pnp.png"></a>
    </td>
  </tr>
} : "") . qq{
</table>

</body>}
);

my $rrdimage = MIME::Entity->build(
	Data		=> $rrd,
	Type		=> 'image/png',
	Id		=> '<pnp.png>',
	Encoding	=> 'base64'
) if ($rrd);
$alt->add_part($txt_content);
$alt->add_part($html_content);
$head->add_part($alt);
$head->add_part($rrdimage) if ($rrd);

$head->attach(
	Path		=> $logo,
	Type		=> 'image/png',
	Id		=> '<sblogo.png>',
	Encoding	=> 'base64'
);


open SENDMAIL, '|/usr/sbin/sendmail -t';
$head->print(\*SENDMAIL);
close SENDMAIL;


