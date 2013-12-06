check_storwize.py
=================

Nagios plugin to check the status of a remote Storwize disk array.

This plugin is designed to be syntactically compatible with check_storwize.sh from nagios exchange
with the following differences:

  - Outputs performance data
  - GPL License
  - Written in python
  - More stable plugin results when disk array is broken


USAGE
=============
```
 python check_storwize.py --help
Usage: check_storwize.py [options]

Options:
  -h, --help            show this help message and exit
  -H HOSTNAME, -M HOSTNAME, --hostname=HOSTNAME
                        Hostname or ip address
  -U USER, --user=USER  Log in as this user to storwize
  -Q QUERY, --query=QUERY
                        Query to send to storwize (see also -L)
  -L, --list-queries    List of valid queries
  --test                Run this plugin in test mode

  Generic Options:
    --timeout=50        Exit plugin with unknown status after x seconds
    --threshold=range   Thresholds in standard nagios threshold format
    --th=range          Same as --threshold
    --extra-opts=@file  Read options from an ini file. See
                        http://nagiosplugins.org/extra-opts
    -d, --debug         Print debug info

  Display Options:
    -v, --verbose       Print more verbose info
    --no-perfdata       Dont show any performance data
    --no-longoutput     Hide longoutput from the plugin output (i.e. only
                        display first line of the output)
    --no-summary        Hide summary from plugin output
    --get-metrics       Print all available metrics and exit (can be combined
                        with --verbose)
    --legacy            Deprecated, do not use
```

EXAMPLES
========
```
# List array status
python check_storwize -H remote_host -U username -Q lsarray

# List vdisk status
python check_storwize -H remote_host -U username -Q lsarray

```


Valid modes
===========
The following is a list of valid modes (at the time of this writing). For an up-to-date list consult check_storwize -L

  * lsarray
  * lsdrive
  * lsenclosurebattery
  * lsenclosurecanister
  * lsenclosurepsu
  * lsenclosureslot
  * lsenclosure
  * lsmdiskgrp
  * lsmdskgrp
  * lsmgrp
  * lsrcrelationship
  * lsvdisk
