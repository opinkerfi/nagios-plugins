#!/usr/bin/env python
#
#   Copyright Marius Rieder <marius.rieder@inf.ethz.ch> 2008
#
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
# 

"""Nagios plugin to test if a file can be fetched ftom a tftp in pure python."""

__version__ = 1.0

import sys
import time
import signal
import socket
import struct
import optparse

# Standard Nagios return codes
OK       = 0
WARNING  = 1
CRITICAL = 2
UNKNOWN  = 3

# TFTP Error Code
errmsgs = {
    1: "File not found",
    2: "Access violation",
    3: "Disk full or allocation exceeded",
    4: "Illegal TFTP operation",
    5: "Unknown transfer ID",
    6: "File already exists",
    7: "No such user",
    8: "Failed to negotiate options"
}


def end(status, message):
    """exits the plugin with first arg as the return code and the second
    arg as the message to output"""
        
    if status == OK:
        print "TFTP OK: %s" % message
        sys.exit(OK)
    elif status == WARNING:
        print "TFTP WARNING: %s" % message
        sys.exit(WARNING)
    elif status == CRITICAL:
        print "TFTP CRITICAL: %s" % message
        sys.exit(CRITICAL)
    else:
        print "UNKNOWN: %s" % message
        sys.exit(UNKNOWN)

def timeout_hook():
    end(UNKNOWN, "Timeout")
    

def main():
    """parses args and calls func to test raid arrays"""

    parser = optparse.OptionParser()

    parser.add_option(  "-H",
                        "--host",
                        dest="host",
                        help="Hostname to test.")

    parser.add_option(  "-P",
                        "--port",
                        dest="port",
                        default=69,
                        help="Portnumber to connect to.")

    parser.add_option(  "-f",
                        "--file",
                        dest="file",
                        help="Filename to fetch.")

    parser.add_option(  "-t",
                        "--timeout",
                        dest="timeout",
                        default=15,
                        help="Filename to fetch.")

    parser.add_option(  "-v",
                        "--verbose",
                        action="count",
                        dest="verbosity",
                        help="Verbose mode. Good for testing plugin. By \
default only one result line is printed as per Nagios standards")

    parser.add_option( "-V",
                        "--version",
                        action = "store_true",
                        dest = "version",
                        help = "Print version number and exit" )

    (options, args) = parser.parse_args()

    verbosity   = options.verbosity
    version     = options.version
    host        = options.host
    port        = options.port
    file        = options.file
    timeout     = options.timeout

    if args:
        parser.print_help()
        sys.exit(UNKNOWN)

    if version:
        print __version__
        sys.exit(OK)
        
    if host == None or file == None or not timeout.isdigit():
        parser.print_help()
        sys.exit(UNKNOWN)
    
    timeout = int(timeout)
    
    # Build TFTP REQ Package
    pkg = struct.pack("!H%dsx5sx" % len(file), 1, file, "octet")
    if verbosity:
        print "Package: %s" % repr(pkg)
    
    signal.signal(signal.SIGALRM, timeout_hook)
    signal.alarm(timeout)
    
    t1 = time.time()
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(pkg, (host, port))
    size = 0
    
    while True:
        (data, src) = sock.recvfrom(1024)
        (opcode, block) = struct.unpack("!HH", data[0:4])
        if opcode == 3:
            # Build TFTP ACK Package
            pkg = struct.pack("!HH", 4, block)
            if verbosity:
                print "Package: %s" % repr(pkg)
            sock.sendto(pkg, src)
            size += len(data) - 4
            if len(data) < 516:
                end(OK, "%d Byte received | time=%2.5f" % (size, time.time() - t1))
        elif opcode == 5:
            end(CRITICAL, "%s: '%s'" % (errmsgs[block], data[4:-1]))
        else:
            end(CRITICAL, "File REQ not working.")
    
    signal.alarm(0)



if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print "Caught Control-C..."
        sys.exit(CRITICAL)
