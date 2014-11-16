#!/usr/bin/python

from pynag.Plugins import simple as Plugin, WARNING, CRITICAL, UNKNOWN, OK
from subprocess import Popen, PIPE
import os


def main():
    global plugin

    plugin = Plugin(must_threshold=False)
    plugin.add_arg("l", "logical-volume",
                   "Comma seperated list of VG/LV, eg vg00/data,vg00/snap",
                   required=False)
    plugin.add_arg("V", "volume-group",
                   "Comma seperated list of VG, eg vg00,vg01",
                   required=False)
    plugin.add_arg("a", "check-all", "Check all LVs", required=False,
                   action="store_true")
    plugin.activate()

    lvs = plugin["logical-volume"] and plugin["logical-volume"].split(
        ",") or []
    vgs = plugin["volume-group"] and plugin["volume-group"].split(",") or []

    if not lvs and not vgs and not plugin['check-all']:
        plugin.parser.error(
            "Either logical-volume or volume-group must be specified")
    elif plugin['check-all'] and ( lvs or vgs ):
        plugin.parser.error(
            "Mixing check-all and logical-volume or volume-group does not make sense")

    check_mirror(lvs, vgs, plugin['check-all'], plugin['host'])

    (code, message) = (plugin.check_messages(joinallstr="\n"))
    plugin.nagios_exit(code, message)


def check_mirror(lv_list, vg_list, check_all, hostname):
    # Ensure the right locale for text parsing
    """

        :rtype : None
        """
    # Change lang setting for string consitency
    env = os.environ.copy()
    env['LC_ALL'] = 'C'

    # Remote execution
    if hostname:
        cmd = ['check_nrpe', '-H', hostname, '-c', 'get_lvm_mirrors']
        # Local
    else:
        cmd = ["lvs", "--separator", ";", "-o",
               "vg_name,lv_name,lv_attr,copy_percent"]
    # Execute lvs
    ret = None
    lvs_output = None
    try:
        lvs = Popen(cmd, stdout=PIPE, shell=False, env=env)
        ret = lvs.wait()
        lvs_output = lvs.stdout.readlines()
    except Exception, e:
        plugin.nagios_exit(UNKNOWN, "Unable to execute lvs: %s" % (e))

    if ret != 0:
        plugin.nagios_exit(CRITICAL,
                       "lvs execution failed, return code %i" % (ret))
    all_lvs = []
    all_vgs = []

    # Loop through lvs output
    linenumber = 0
    for l in lvs_output:
        linenumber += 1
        try:
            vg_name, lv_name, lv_attr, copy_percent = l.strip().split(";")
        except ValueError as error:
            plugin.add_message(UNKNOWN,
                               "Unable to parse lvs line %i: %s\n%s" % (
                                   linenumber, error, l))
            continue
        all_lvs.append("%s/%s" % (vg_name, lv_name))
        if vg_name not in all_vgs:
            all_vgs.append(vg_name)

        if check_all or "%s/%s" % (
                vg_name, lv_name) in lv_list or vg_name in vg_list:
            if lv_attr[0] != "m" and lv_attr[0] != "M":
                plugin.add_message(CRITICAL,
                                   "LV %s/%s not mirrored" % (vg_name, lv_name))
            elif lv_attr[2] != "a":
                plugin.add_message(CRITICAL,
                                   "LV %s/%s not active" % (vg_name, lv_name))
            elif lv_attr[5] != "o":
                plugin.add_message(CRITICAL,
                                   "LV %s/%s not open" % (vg_name, lv_name))
            elif float(copy_percent or 0) < 100:
                plugin.add_message(WARNING, "LV %s/%s Copy Percent %s" % (
                    vg_name, lv_name, copy_percent))
            else:
                plugin.add_message(OK, "LV %s/%s functioning" % (vg_name, lv_name))

    # Find lvs that were specified in cmd line but were not found via lvs
    for v in vg_list:
        if v not in all_vgs:
            plugin.add_message(CRITICAL, "VG %s not found" % (v))

    # Find lvs that were specified in cmd line but were not found via lvs
    for l in lv_list:
        if l not in all_lvs:
            plugin.add_message(CRITICAL, "LV %s not found" % (l))

if __name__ == "__main__":
    main()


