#!/usr/bin/python
#
# Script for checking global health of host running VMware ESX/ESXi
#
# Licence : GNU General Public Licence (GPL) http://www.gnu.org/
# Pre-req : pywbem
#
#@---------------------------------------------------
#@ History
#@---------------------------------------------------
#@ Date   : 20080820
#@ Author : David Ligeret
#@ Reason : Initial release
#@---------------------------------------------------
#@ Date   : 20080821
#@ Author : David Ligeret
#@ Reason : Add verbose mode
#@---------------------------------------------------
#@ Date   : 
#@ Author : 
#@ Reason : 
#@---------------------------------------------------
#

import sys
import time
import pywbem

NS = 'root/cimv2'

# define classes to check 'OperationStatus' instance
ClassesToCheck = [
	'CIM_ComputerSystem',
	'CIM_NumericSensor',
	'CIM_Memory',
	'CIM_Processor',
	'CIM_RecordLog',
	'OMC_DiscreteSensor',
	'VMware_StorageExtent',
	'VMware_Controller',
	'VMware_StorageVolume',
	'VMware_Battery',
	'VMware_SASSATAPort'
]

# define exit codes
ExitOK = 0
ExitWarning = 1
ExitCritical = 2
ExitUnknown = 3

def verboseoutput(message, verbose) :
	if verbose == 1:
		print "%s %s" % (time.strftime("%Y%m%d %H:%M:%S"), message)

# check input arguments
if len(sys.argv) < 4:
	sys.stderr.write('Usage   : ' + sys.argv[0] + ' hostname user password\n')
	sys.stderr.write('Example : ' + sys.argv[0] + ' https://myesxi:5989 root password\n')
	sys.exit(1)
verbose = 0
if len(sys.argv) == 5 :
	if sys.argv[4] == "verbose" :
		verbose = 1

# connection to host
verboseoutput("Connection to "+sys.argv[1], verbose)
wbemclient = pywbem.WBEMConnection(sys.argv[1], (sys.argv[2], sys.argv[3]), NS)

# run the check for each defined class
GlobalStatus = ExitOK
ExitMsg = ""
for classe in ClassesToCheck :
	verboseoutput("Check classe "+classe, verbose)
	instance_list = wbemclient.EnumerateInstances(classe)
	for instance in instance_list :
		elementName = instance['ElementName']
		verboseoutput("Element Name = "+elementName, verbose)
		if instance['OperationalStatus'] is not None :
			elementStatus = instance['OperationalStatus'][0]
			verboseoutput("Element Op Status = %d" % elementStatus, verbose)
			interpretStatus = {
				0  : ExitOK,		# Unknown
				1  : ExitCritical,	# Other
				2  : ExitOK,		# OK
				3  : ExitWarning,	# Degraded
				4  : ExitWarning,	# Stressed
				5  : ExitWarning,	# Predictive Failure
				6  : ExitCritical,	# Error
				7  : ExitCritical,	# Non-Recoverable Error
				8  : ExitWarning,	# Starting
				9  : ExitWarning,	# Stopping
				10 : ExitCritical,	# Stopped
				11 : ExitOK,		# In Service
				12 : ExitWarning,	# No Contact
				13 : ExitCritical,	# Lost Communication
				14 : ExitCritical,	# Aborted
				15 : ExitOK,		# Dormant
				16 : ExitCritical,	# Supporting Entity in Error
				17 : ExitOK,		# Completed
				18 : ExitOK,		# Power Mode
				19 : ExitOK,		# DMTF Reserved
				20 : ExitOK		# Vendor Reserved
			}[elementStatus]
			if (interpretStatus == ExitCritical) :
				verboseoutput("GLobal exit set to CRITICAL", verbose)
				GlobalStatus = ExitCritical
				ExitMsg += "CRITICAL : %s<br>" % elementName
			if (interpretStatus == ExitWarning and GlobalStatus != ExitCritical) :
				verboseoutput("GLobal exit set to WARNING", verbose)
				GlobalStatus = ExitWarning
				ExitMsg += "WARNING : %s<br>" % elementName

if GlobalStatus == 0 :
	print "OK"
else :
	print ExitMsg
sys.exit (GlobalStatus)
