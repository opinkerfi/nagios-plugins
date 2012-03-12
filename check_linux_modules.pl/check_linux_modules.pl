#!/usr/bin/perl -w
##
## Copyright 2010, Tomas Edwardsson 
##
## This script is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This script is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
use strict;

if (!@ARGV) {
	print "CRITICAL usage, $0 [module module..]\n";
	exit 2;
}

sub check_modules($@) {
	my $kernel = shift;
	my @modules = @_;

	my $failed_string = '';
	foreach my $mod (@modules) {
		if (!-f "/lib/modules/$kernel/$mod") {
			$failed_string .= "/lib/modules/$kernel/$mod, ";
		}
	}
	chop($failed_string) for (0..1);
	if ($failed_string) {
		print "WARNING, missing modules for boot kernel, $failed_string\n";
		exit 1;
	}
	print "OK, all modules in place\n";
	exit 0;
}


sub get_latest_kernel() {

	
	unless (open GRUBCONF, '</etc/grub.conf') {
		print "CRITICAL, Unable to open /etc/grub.conf: $!\n";
		exit 2;
	};

	my $line;

	# Set starting default for format detection
	my $default = -1;
	my $titlenum = 0;
	my $title = '';
	my $kernel = '';

	# Read through grub.conf
	while (my $line = <GRUBCONF>) {
		# Strip newline characters
		chomp($line);

		# Search for default=\d
		if ($default == -1) {
			if ($line =~ /^default=(\d+)$/) {
				$default = ($1 + 1);
			}
		# Search title
		} elsif (!$title) {
			if ($line =~ /^title /) {
				$titlenum++;
			}
			$title = $line if ($titlenum == $default);
		# Find the kernel
		} else {
			if ($line =~ /kernel.\/vmlinuz-(\S+) /) {
				$kernel = $1;
				last;
			}
		}
	}
	if ($default == -1) {
		print "WARNING, No default= found in grub.conf\n";
		exit 1;
	} elsif (!$title) {
		print "WARNING, No title found for default=$default in grub.conf\n";
		exit 1;
	} elsif (!$kernel) {
		print "WARNING, No kernel found for kernel title \"$title\"\n";
		exit 1;
	}
	return $kernel;
}


my $kernel = get_latest_kernel();
check_modules($kernel, @ARGV);

__END__

title Red Hat Enterprise Linux Server (2.6.18-128.1.6.el5PAE)
        root (hd0,0)
        kernel /vmlinuz-2.6.18-128.1.6.el5PAE ro root=/dev/vg00/LogVolRoot

