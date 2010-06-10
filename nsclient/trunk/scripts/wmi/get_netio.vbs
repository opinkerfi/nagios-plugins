' Copyright 2010 Opin Kerfi ehf ok.is.
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
' Author Pall Sigurdsson <palli at opensource.is>

'*************************************************************************************************
strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
set objRefresher = CreateObject("WbemScripting.SWbemRefresher")
Set colDisks = objRefresher.AddEnum _
    (objWMIService, "Win32_PerfRawData_Tcpip_NetworkInterface"). _
        objectSet
objRefresher.Refresh
strOut = "Network Interfaces: "
strPerfdata = " | "
    For Each objDisk in colDisks
        objRefresher.Refresh
        strOut = strOut & " " & objDisk.Name & " "
        strPerfdata = strPerfData & " 'net_sent_" & objDisk.Name & "'=" & objDisk.BytesSentPerSec 
        strPerfdata = strPerfData & " 'net_recv_" & objDisk.Name & "'=" & objDisk.BytesReceivedPerSec 
    Next
Wscript.Echo strOut & strPerfdata


