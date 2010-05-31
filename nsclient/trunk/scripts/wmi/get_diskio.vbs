' Copyright 2007 GroundWork Open Source Inc.
'
' This program is free software; you can redistribute it and/or
' modify it under the terms of the GNU General Public License
' as published by the Free Software Foundation; version 2
' of the License.
'
' This program is distributed in the hope that it will be useful,
' but WITHOUT ANY WARRANTY; without even the implied warranty of
' MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
' GNU General Public License for more details.
'
'
' Author Dr. Pall Sigurdsson <palli at opensource.is>

'*************************************************************************************************
strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
Set colDisks = objRefresher.AddEnum _
    (objWMIService, "win32_perfformatteddata_perfdisk_logicaldisk"). _
        objectSet
objRefresher.Refresh
strOut = "Logical Disks: "
strPerfdata = " | "
    For Each objDisk in colDisks
	objRefresher.Refresh
	strOut = strOut & " " & objDisk.Name & " " 
	strPerfdata = strPerfData & " 'AvgDiskQueueLength_" & objDisk.Name & "'=" & objDisk.AvgDiskQueueLength
	strPerfdata = strPerfData & " 'DiskReadBytesPerSec_" & objDisk.Name & "'=" & objDisk.DiskReadBytesPerSec
	strPerfdata = strPerfData & " 'DiskWriteBytesPerSec_" & objDisk.Name & "'=" & objDisk.DiskWriteBytesPerSec
	strPerfdata = strPerfData & " 'DiskReadsPerSec_" & objDisk.Name & "'=" & objDisk.DiskReadsPerSec
	strPerfdata = strPerfData & " 'DiskWritesPerSec_" & objDisk.Name & "'=" & objDisk.DiskWritesPerSec
	strPerfdata = strPerfData & " 'PercentDiskReadTime_" & objDisk.Name & "'=" & objDisk.PercentDiskReadTime
	strPerfdata = strPerfData & " 'SplitIOPerSec_" & objDisk.Name & "'=" & objDisk.SplitIOPerSec
	strPerfdata = strPerfData & " 'PercentDiskTime_" & objDisk.Name & "'=" & objDisk.PercentDiskTime
	strPerfdata = strPerfData & " 'AvgDiskBytesPerTransfer_" & objDisk.Name & "'=" & objDisk.AvgDiskBytesPerTransfer
    Next
Wscript.Echo strOut & strPerfdata
