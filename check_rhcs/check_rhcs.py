#!/bin/env python
# Gather the cluster state and the current node state
#
# Output example:
#<clustat version="4.1.1">
#  <cluster name="LabCluster" id="22068" generation="172"/>
#  <quorum quorate="1" groupmember="1"/>
#  <nodes>
#    <node name="clusternode1.lab.inetu.net" state="1" local="0" \
#          estranged="0" rgmanager="1" rgmanager_master="0" qdisk="0" nodeid="0x00000001"/>
#    <node name="clusternode2.lab.inetu.net" state="1" local="1" \
#          estranged="0" rgmanager="1" rgmanager_master="0" qdisk="0" nodeid="0x00000002"/>
#    <node name="/dev/disk/by-id/scsi-36002219000b9642b000027124a3b61f1-part1" state="1" \
#          local="0" estranged="0" rgmanager="0" rgmanager_master="0" qdisk="1" nodeid="0x00000000"/>
#  </nodes>
#  <groups>
#    <group name="service:MySQL" state="112" state_str="started" flags="0" flags_str="" \
#           owner="clusternode2.lab.inetu.net" last_owner="clusternode1.lab.inetu.net" restarts="0" \
#           last_transition="1245765274" last_transition_str="Tue Jun 23 09:54:34 2009"/>
#  </groups>
#</clustat>
#
# Frank Clements <frank @ sixthtoe.net>
#
# INFO : In RHEL 5, there is a bug in clustat preventing non-root users to use 
# clustat. See https://bugzilla.redhat.com/show_bug.cgi?id=531273
# You might need to use setuid on clustat to change this if rgmanager cannot be
# upgraded to 3.0.7+
# $chown root:nagios /usr/sbin/clustat
# $chmod u+s /usr/sbin/clustat


import xml.dom.minidom
import os
import sys, socket
import getopt

def usage():
    """
    Display usage information
    """
    print """
Usage: """ + sys.argv[0] + """ ([-s serviceName] | [-c])

-c, --cluster
   Gathers the overall cluster status for the local node
-s, --service
   Gets the stats of the named service
-Z, --suspended
   Checks whether there are any suspended services
-h, --help
   Display this
"""

def getQuorumState(dom):
    """
    Get the quorum state.  This is a single inline element which only 
    has attributes and no children elements.
    """
    quorumList = dom.getElementsByTagName('quorum')
    quorumElement = quorumList[0]

    return quorumElement.attributes['quorate'].value


def getClusterName(dom):
    """
    Get the name of the cluster from the clustat output.
    This assumes only a single cluster is running for the moment.
    """
    clusterList = dom.getElementsByTagName('cluster')
    clusterElement = clusterList[0]

    return clusterElement.attributes['name'].value


def getLocalNodeState(dom):
    """
    Get the state of the local node
    """
    nodesList = dom.getElementsByTagName('node')
    nodeState = {}
    
    for node in nodesList:
        if node.attributes['local'].value == "1":
            nodeState['name'] = node.attributes['name'].value
            nodeState['state'] = node.attributes['state'].value 
            nodeState['rgmanager'] = node.attributes['rgmanager'].value 

        elif node.attributes['qdisk'].value == "1":
            if node.attributes['state'].value != "1":
                print "CRITICAL: Quorum disk " + node.attributes['name'].value + " is unavailable!"
                sys.exit(2)   
  
    return nodeState


def getServiceState(dom, service):
    """ 
    Get the state of the named service
    """
    groupList = dom.getElementsByTagName('group')
    serviceState = {}
    for group in groupList:
        if group.attributes['name'].value in (service,"service:"+service,"vm:"+service):
            serviceState['owner'] = group.attributes['owner'].value
            serviceState['state'] = group.attributes['state_str'].value
            serviceState['flags'] = group.attributes['flags_str'].value
                 
    return serviceState


def main():
    try:
        opts, args = getopt.getopt(sys.argv[1:], 's:cZh', ['service=', 'cluster', 'supsended', 'help'])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    check_suspend = False
    typeCheck = None
    for o, a in opts:
        if o in ('-c', '--cluster'):
            typeCheck = 'cluster'
        if o in ('-s', '--service'):
            typeCheck = 'service'
            serviceName = a
        if o in ('-Z', '--suspended'):
            check_suspend = True
        if o in ('-h', '--help'):
            usage()
            sys.exit()

    if typeCheck == None:
        usage()
        sys.exit()

    try:
        clustatOutput = os.popen('/usr/sbin/clustat -fx')
        dom = xml.dom.minidom.parse(clustatOutput)
    except Exception, e:
        print "Error: could not parse output of : '/usr/sbin/clustat -fx': ", e
        sys.exit(3)
    if typeCheck == 'cluster':

        # First we query for the state of the cluster itself.
        # Should it be found that the cluster is not quorate we alert and exit immediately
        cluster = getClusterName(dom)
        qState  = getQuorumState(dom)

        # There are some serious problems if the cluster is inquorate so we simply alert immediately!
        if qState != "1":
            print "CRITICAL: Cluster " + cluster + " is inquorate!"
            sys.exit(2)

        # Now we find the status of the local node from clustat.
        # We only care about the local state since this way we can tie the alert to the host.
        nodeStates = getLocalNodeState(dom) 
		if nodeStates == {}:
            print "UNKNOWN: Local node informations couldn't be found!"
			sys.exit(3)
			if nodeStates['state'] != "1":
				print "WARNING: Local node state is offline!"
				sys.exit(1)
			elif nodeStates['rgmanager'] != "1":
				print "CRITICAL: RGManager service not running on " + nodeStates['name'] + "!"
				sys.exit(2) 
			else:
				print "OK: Cluster node " + nodeStates['name'] + " is online and cluster is quorate."
				sys.exit(0)

    elif typeCheck == 'service':
        serviceState = getServiceState(dom, serviceName)
        if serviceState['state'] != 'started':
            print "CRITICAL: Service " + serviceName + " on " + serviceState['owner'] + " is in " + serviceState['state'] + " state"
            sys.exit(2)
        elif check_suspend is True and serviceState['flags'] == 'frozen':
            print "WARNING: Service " + serviceName + " on " + serviceState['owner'] + " is in " + serviceState['flags'] + " state"
            sys.exit(1)
        else:
            print "OK: Service " + serviceName + " on " + serviceState['owner'] + " is in " + serviceState['state'] + " state"
            sys.exit(0)


if __name__ == "__main__":
    main()
