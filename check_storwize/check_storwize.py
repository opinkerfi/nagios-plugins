#!/usr/bin/env python

from pynag.Plugins import PluginHelper, ok, warning, critical, unknown
from pynag.Utils import runCommand
from collections import namedtuple

valid_queries = "lsarray lsdrive lsenclosurebattery lsenclosurecanister lsenclosurepsu lsenclosureslot lsenclosure lsmdiskgrp lsmdskgrp lsmgrp lsrcrelationship lsvdisk"

p = PluginHelper()
p.add_option("-H", "--hostname", '-M', help="Hostname or ip address", dest="hostname")
p.add_option("-U", "--user", help="Log in as this user to storwize", dest="user", default="nagios")
p.add_option("-Q", "--query", help="Query to send to storwize (see also -L)", dest="query", default="lsarray")
p.add_option("-L", "--list-queries", help="List of valid queries", dest="list_queries", action="store_true")
p.add_option("--test", help="Run this plugin in test mode", dest="test", action="store_true")

p.parse_arguments()

if not p.options.hostname:
    p.parser.error("Required options -H is missing")
if p.options.query not in valid_queries.split():
    p.parser.error("%s does not look like a valid query. Use -L for a list of valid queries" % p.options.query)
if p.options.list_queries is True:
    p.parser.error("Valid Queries: %s" % valid_queries)

query = p.options.query


# Connect to remote storwize and run a connect
def run_query():
    """ Connect to a remote storwize box and run query  """
    command = "ssh %s@%s %s -delim ':'" % (p.options.user, p.options.hostname, p.options.query)
    if p.options.test:
        command = "cat tests/%s.txt" % (p.options.query)
    return_code, stdout, stderr = runCommand(command)

    if return_code != 0:
        p.status(unknown)
        p.add_summary("Got error %s when trying to log into remote storwize box" % return_code)
        p.add_long_output("\ncommand:\n===============\n%s" % command)
        p.add_long_output("\nStandard output:\n==============\n%s" % (stdout))
        p.add_long_output("\nStandard stderr:\n==============\n%s" % (stderr))
        p.exit()
    if stderr:
        p.status(unknown)
        p.add_summary("Error when connecting to storwize: %s" % stderr)
        p.exit()

    # Parse the output of run query and return a list of "rows"
    lines = stdout.splitlines()
    top_line = lines.pop(0)
    headers = top_line.split(':')
    Row = namedtuple('Row', ' '.join(headers))
    rows = []
    for i in lines:
        i = i.strip()
        columns = i.split(':')
        row = Row(*columns)
        rows.append(row)
    return rows


def check_lsmdiskgrp():
    p.add_summary("%s diskgroups found" % (len(rows)))
    p.add_metric("number of groups", len(rows))
    for row in rows:
        if row.status != 'online':
            p.status(critical)
            p.add_summary("group %s is %s." % (row.name, row.status))
        p.add_long_output("%s: used: %s out of %s" % (row.name, row.used_capacity, row.capacity))
        # Add a performance metric
        metric_name = "%s_capacity" % row.name
        p.add_metric(metric_name, value=row.used_capacity, max=row.capacity)


def check_lsdrive():
    p.add_summary("%s drives found" % (len(rows)))
    p.add_metric("number of drives", len(rows))
    for row in rows:
        if row.status != 'online':
            p.add_summary("drive %s is %s" % (row.id, row.status))


def check_lsenclosurebattery():
    p.add_summary("%s batteries found" % (len(rows)))
    p.add_metric("number of batteries", len(rows))
    for row in rows:
        if row.status != 'online':
            p.add_summary("battery %s:%s is %s" % (row.enclosure_id, row.battery_id, row.status))


def check_lsvdisk():
    p.add_summary("%s disks found" % (len(rows)))
    p.add_metric("number of disks", len(rows))
    for row in rows:
        if row.status != 'online':
            p.add_summary("disk %s is %s" % (row.name, row.status))


def check_lsarray():
    p.add_summary("%s arrays found" % (len(rows)))
    p.add_metric("number of arrays", len(rows))
    for row in rows:
        if row.status != 'online':
            p.add_summary("array %s is %s." % (row.name, row.status))
            p.status(critical)
        # Add some performance metrics
        metric_name = row.mdisk_name + "_capacity"
        p.add_metric(metric_name, value=row.capacity)

# Run our given query, and parse the output
rows = run_query()

if query == 'lsmdiskgrp':
    check_lsmdiskgrp()
elif query == 'lsarray':
    check_lsarray()
elif query == 'lsdrive':
    check_lsdrive()
elif query == 'lsvdisk':
    check_lsvdisk()
elif query == 'lsenclosurebattery':
    check_lsenclosurebattery()
else:
    p.status(unknown)
    p.add_summary("unsupported query: %s. See -L for list of valid queries" % query)
    p.exit()

# Check metrics and exit
p.check_all_metrics()
p.exit()
