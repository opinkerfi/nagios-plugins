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
' Author Dr. Dave Blunt at GroundWork Open Source Inc. (dblunt@groundworkopensource.com)

'*************************************************************************************************
'                                        Public Variable
'*************************************************************************************************
Const intOK = 0
Const intUnknown = 3
Const intError = 3

Dim argcountcommand
Dim arg(20)
Dim strComputer
Dim strUser
Dim strPass
Dim strNameSpace
Dim strDescription
Dim strCommandName
Dim strResultTemp
Dim strResult

Dim ArgCount
Dim strArgMain(10)
Dim strArgSortDes(10)
Dim strArgDetailDes(10)
Dim strArgExample(10)

strInfo=""

'*************************************************************************************************
'                                        Functions and Subs
'*************************************************************************************************

'-------------------------------------------------------------------------------------------------
'Function Name:     f_Error.
'Descripton:        Display an error notice include : Error Number and Error Description.
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_Error()
	
		nbrError = err.number
		if (nbrError <> 0 ) then
			Select Case nbrError
				Case 462, -2147023174
					strExitMsg = "Timeout connecting to WMI on this host! Error Number: " & nbrError & " Description: " & err.description
				Case -2147024891
					strExitMsg = "Authentication failure to remote host! Error Number: " & nbrError & " Description: " & err.description
				Case -2147217392
					strExitMsg = "Error! Number: " & nbrError & " Description: Invalid Class"
				Case Else
					strExitMsg = "Error! Number: " & nbrError & " Description: " & err.description
			End Select
			wscript.echo strExitMsg
			wscript.quit(intUnknown)
		end if

	End Function

'-------------------------------------------------------------------------------------------------
'Function Name:     f_Help.
'Descripton:        Display help of command include : Description, Arguments, Examples
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_Help()
	
		Dim strHelp
		
		
		Dim i
		Dim strtemp1
		Dim strtemp2
		Dim strtemp3
		
		strHelp=""
		
		strtemp1=""
		strtemp2=""
		strtemp3=""

		for i=1 to ArgCount
			strtemp1=strtemp1 & " " & strArgMain(i) & " " & strArgSortDes(i)
			strtemp2=strtemp2 & strArgMain(i) & " " & strArgSortDes(i) & "	" & strArgDetailDes(i) & "." & vbCrlF
			strtemp3=strtemp3 & " " & strArgMain(i) & " " & strArgExample(i)
		next
		
								'/////////////////////		
		
  		strHelp=strHelp & strDescription & " If your Local Machine has the same Administrator account and password as the Remote Machine then you don't have to use the two (three) last parameters."&vbCrlF&vbCrlF
  		strHelp=strHelp & "cscript " & strCommandName & strtemp1 & " [-user username -pass password -domain domain]"
  		strHelp=strHelp & vbCrlF
  		strHelp=strHelp & strtemp2  		
    	      strHelp=strHelp & "-user username		Account Administrator on Remote Machine." & vbCrlF
  		strHelp=strHelp & "-pass password		Password Account Administrator on Remote Machine." & vbCrlF
  		strHelp=strHelp & "-domain domain		Domain Name on Remote Machine." & vbCrlF
  		strHelp=strHelp & vbCrlF  		
  		strHelp=strHelp & "Example: cscript " & strCommandName & strtemp3 & " [-user Ser1\Administrator -pass password -domain workgroup]." & vbCrlF
  		strHelp=strHelp & vbCrlF
  		strHelp=strHelp & "For Help Command: cscript " & strCommandName & " -h (or --help)." & vbCrlF
  		strHelp=strHelp & vbCrlF
  		strHelp=strHelp & "Note: information can be one or multiple of network_interfaces, logical_disks, installed_services, running_processes, all_processors or *." & vbCrlF
  		strHelp=strHelp & "And if get multiple infomation, the information must be enclosed in multiple quotes and separate by commas." & vbCrlF
  		strHelp=strHelp & "Example: cscript get_computer_info.vbs -h Ser1 -i ""network_interfaces,logical_disks,install_services"" [-user SER1\Administrator -pass password] " & vbCrlF 
  		Wscript.echo strHelp
		
	End Function
'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetAllArg.
'Descripton:        Get all of arguments from command.
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetAllArg()
	
		On Error Resume Next
		
		Dim i
		
		argcountcommand=WScript.Arguments.Count
		
		for i=0 to argcountcommand-1
  			arg(i)=WScript.Arguments(i)
		next
		
	End Function
'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetOneArg.
'Descripton:        Get an argument from command.
'Input:				Yes.
'						strName: Name of argument
'Output:			Value.
'-------------------------------------------------------------------------------------------------
	Function f_GetOneArg(strName)
	
		On Error Resume Next
		
		Dim i
		for i=0 to argcountcommand-1
			if (Ucase(arg(i))=Ucase(strName)) then
				f_GetOneArg=arg(i+1)
				Exit Function
			end if
		next
		
	End Function

'-------------------------------------------------------------------------------------------------
'Function Name:     f_TestLocalCommand.
'Descripton:        Test structure of command run at local host.
'Input:				No.
'Output:			Yes.
'-------------------------------------------------------------------------------------------------
	Function f_TestLocalCommand()

		On Error Resume Next
		
		Dim i,j
		Dim temp
		Dim count
		Dim check(10)
		
		count=0
		
		for j=1 to ArgCount
			check(j)=0
		next

		if (argcountcommand<>ArgCount*2) then
			f_TestLocalCommand=0
		else
			for i=0 to argcountcommand-1
				if (i mod 2=0) then
					temp=UCase(arg(i))
					for j=1 to ArgCount
						if (temp=UCase(strArgMain)) and (check(j)=0) then
							check(j)=1
							count=count+1
							j=ArgCount
						end if
					next
				end if
			next
			if count=ArgCount then
				f_TestLocalCommand=1
			else
				f_TestLocalCommand=0
			end if
		end if

	End Function
'-------------------------------------------------------------------------------------------------
'Function Name:     f_TestRemoteCommand.
'Descripton:        Test structure of command run at remote host.
'Input:				No.
'Output:			Yes.
'-------------------------------------------------------------------------------------------------
	Function f_TestRemoteCommand()

		On Error Resume Next
		
		Dim i,j
		Dim temp
		Dim count
		Dim check(10)
		Dim extra(5)
		
		count=0
		
		for j=1 to ArgCount
			check(j)=0
		next
		
		for j=1 to 3
			extra(j)=0
		next


		if (argcountcommand=(ArgCount+2)*2) or (argcountcommand=(ArgCount+3)*2) then
			for i=0 to argcountcommand-1
				if (i mod 2=0) then
					temp=UCase(arg(i))
					if (temp="-USER" and extra(1)=0) then
						extra(1)=1
						count=count+1
					else
						if (temp="-PASS" and extra(2)=0) then
							extra(2)=1
							count=count+1
						else
							if (temp="-DOMAIN" and extra(3)=0) then
								extra(3)=1
								count=count+1
							else					
								for j=1 to ArgCount
									if (temp=UCase(strArgMain)) and (check(j)=0) then
										check(j)=1
										count=count+1
										j=ArgCount
									end if
								next
							end if
						end if
					end if
				end if
			next
			if (count*2=argcountcommand) then
				f_TestRemoteCommand=1
			else
				f_TestRemoteCommand=0
			end if
		
		else
		  	f_TestremoteCommand=0
		end if

	End Function
	
'-------------------------------------------------------------------------------------------------
'Function Name:     f_LocalInfo.
'Descripton:        Get infomation at Local Host.
'Input:				info.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_LocalInfo(info)
		
		On Error Resume Next
		
		Dim objWMIService, colWMI,objWMI
		strResultTemp = ""
		strOut = ""
		Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\" & strNameSpace)
		f_Error()
		'Depend on strInfo parameters to get the result value
		if(info = "*") then
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_PerfRawData_Tcpip_NetworkInterface")
			for Each objWMI In colWMI
				strOut = strOut & objWMI.Name & ", "
			next
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_LogicalDisk")
			for Each objWMI In colWMI
				strOut1 = strOut1 & objWMI.Name & ", "
			next
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_BaseService")
			for Each objWMI In colWMI
				strOut2 = strOut2 & objWMI.Name & ", "
			next
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_Process")
			for Each objWMI In colWMI
				strOut3 = strOut3 & objWMI.Name & ", "
			next
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_Processor")
			for Each objWMI In colWMI
				strOut4 = strOut4 & objWMI.Name & ", "
			next
			strResultTemp = "; Network Interfaces: " & strOut & "; Logical Disks: " & strOut1 &_
							"; Installed services: " & strOut2 & "; Running Processes: " & strOut3 &_
							"; All Processors: " & strOut4
			Exit Function
		end if
		
		if(info = "network_interfaces") then
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_PerfRawData_Tcpip_NetworkInterface")
			for Each objWMI In colWMI
				strOut = strOut & objWMI.Name & ", "
			next
			strResultTemp = "; Network Interfaces: " & strOut
			Exit Function
		else 
			if(info = "logical_disks") then
				Set colWMI = objWMIService.ExecQuery("Select * from Win32_LogicalDisk")
				for Each objWMI In colWMI
					strOut = strOut & objWMI.Name & ", "
				next
				strResultTemp = "; Logical Disks: " & strOut
				Exit Function
			else 
				if(info = "installed_services") then
					Set colWMI = objWMIService.ExecQuery("Select * from Win32_BaseService")
					for Each objWMI In colWMI
						strOut = strOut & objWMI.Name  & ", "
					next
					strResultTemp = "; Installed Services: " & strOut
					Exit Function
				else 
					if(info = "running_processes") then
						Set colWMI = objWMIService.ExecQuery("Select * from Win32_Process")
						for Each objWMI In colWMI
							strOut = strOut & objWMI.Name & ", "
						next
						strResultTemp = "; Running Processes: " & strOut
						Exit Function
					else 
						if(info = "all_processors") then
							Set colWMI = objWMIService.ExecQuery("Select * from Win32_Processor")
							for Each objWMI In colWMI
								strOut = strOut & objWMI.Name & ", "
							next
							strResultTemp = "; All Processors: " & strOut
							Exit Function
						else
							f_Error()
				  			Wscript.echo "Error! Arguments are wrong."
				  			Wscript.Quit(3)
						end if
					end if
				end if
			end if
		end if
							
	End Function

'-------------------------------------------------------------------------------------------------
'Function Name:     f_RemoteInfo.
'Descripton:        Get infomation at Remote Host.
'Input:				info.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_RemoteInfo(info)
		
		On Error Resume Next
		
		Dim objWMIService, colWMI,objWMI,objSWbemLocator
		Dim strDomain
		strResultTemp = ""
		strOut = ""
		
		Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")

		if ((ArgCount+2)*2=ArgCountCommand) then
			Set objWMIService = objSWbemLocator.ConnectServer _
				(strComputer, strNameSpace , strUser, strPass )	
			f_Error()
		else
			strDomain=f_GetOneArg("-domain")
			Set objWMIService = objSWbemLocator.ConnectServer _
				(strComputer, strNameSpace , strUser, strPass,"MS_409","ntlmdomain:" + strDomain )
			f_Error()
		end if
		
		objWMIService.Security_.ImpersonationLevel = 3
		f_Error()
		'Depend on strInfo parameters to get the result value
		if(info = "*") then
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_PerfRawData_Tcpip_NetworkInterface")
			for Each objWMI In colWMI
				strOut = strOut & objWMI.Name & ", "
			next
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_LogicalDisk")
			for Each objWMI In colWMI
				strOut1 = strOut1 & objWMI.Name & ", "
			next
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_BaseService")
			for Each objWMI In colWMI
				strOut2 = strOut2 & objWMI.Name & ", "
			next
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_Process")
			for Each objWMI In colWMI
				strOut3 = strOut3 & objWMI.Name & ", "
			next
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_Processor")
			for Each objWMI In colWMI
				strOut4 = strOut4 & objWMI.Name & ", "
			next
			strResultTemp = "; Network Interfaces: " & strOut & "; Logical Disks: " & strOut1 &_
							"; Installed services: " & strOut2 & "; Running Processes: " & strOut3 &_
							"; All Processors: " & strOut4
			Exit Function
		end if
		
		if(info = "network_interfaces") then
			Set colWMI = objWMIService.ExecQuery("Select * from Win32_PerfRawData_Tcpip_NetworkInterface")
			for Each objWMI In colWMI
				strOut = strOut & objWMI.Name & ", "
			next
			strResultTemp = "; Network Interfaces: " & strOut
			Exit Function
		else 
			if(info = "logical_disks") then
				Set colWMI = objWMIService.ExecQuery("Select * from Win32_LogicalDisk")
				for Each objWMI In colWMI
					strOut = strOut & objWMI.Name & ", "
				next
				strResultTemp = "; Logical Disks: " & strOut
				Exit Function
			else 
				if(info = "installed_services") then
					Set colWMI = objWMIService.ExecQuery("Select * from Win32_BaseService")
					for Each objWMI In colWMI
						strOut = strOut & objWMI.Name  & ", "
					next
					strResultTemp = "; Installed Services: " & strOut
					Exit Function
				else 
					if(info = "running_processes") then
						Set colWMI = objWMIService.ExecQuery("Select * from Win32_Process")
						for Each objWMI In colWMI
							strOut = strOut & objWMI.Name & ", "
						next
						strResultTemp = "; Running Processes: " & strOut
						Exit Function
					else 
						if(info = "all_processors") then
							Set colWMI = objWMIService.ExecQuery("Select * from Win32_Processor")
							for Each objWMI In colWMI
								strOut = strOut & objWMI.Name & ", "
							next
							strResultTemp = "; All Processors: " & strOut
							Exit Function
						else
							f_Error()
				  			Wscript.echo "Error! Arguments are wrong."
				  			Wscript.Quit(3)
						end if
					end if
				end if
			end if
		end if
							
	End Function
			
'-------------------------------------------------------------------------------------------------
'Function Name:     f_LocalPerfValue.
'Descripton:        Get perform value at Local Host.
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_LocalPerfValue()
		
		On Error Resume Next
		strResult = ""
		info = strInfo
		'sProcess = arg(3)
        first=1
        tam1=10
        if (len(strInfo)>0) then
          do while (tam1>0)
            tam1=InStr(first,strInfo,",")
            if (tam1>0) then
              tam2=Mid(strInfo,first,tam1-first)
              first=tam1+1
              info = tam2
	      f_LocalInfo(Trim(info))
	      strResult = strResult & strResultTemp
  	    end if
          Loop
          tam2=Mid(strInfo,first,len(strInfo))
          info = tam2
          f_LocalInfo(Trim(info))
	      strResult = strResult & strResultTemp
		end if
		strResult = "Host name: " & strComputer & strResult 
		Wscript.Echo strResult
		Wscript.Quit(intOK)
	End Function
'-------------------------------------------------------------------------------------------------
'Function Name:     f_RemotePerfValue.
'Descripton:        Get perform values at Remote Host.
'Input:				No.
'Output:			Values.
'-------------------------------------------------------------------------------------------------
	Function f_RemotePerfValue()
		
		On Error Resume Next
		
		strResult = ""
		info = strInfo
		first=1
        tam1=10
        if (len(strInfo)>0) then
          do while (tam1>0)
            tam1=InStr(first,strInfo,",")
            if (tam1>0) then
              tam2=Mid(strInfo,first,tam1-first)
              first=tam1+1
              info = tam2
	      f_RemoteInfo(Trim(info))
	      strResult = strResult & strResultTemp
  	    end if
          Loop
          tam2=Mid(strInfo,first,len(strInfo))
          info = tam2
          f_RemoteInfo(Trim(info))
	      strResult = strResult & strResultTemp
		end if
		strResult = "Host name: " & strComputer & strResult 
		Wscript.Echo strResult
		Wscript.Quit(intOK)

	End Function
'*************************************************************************************************
'                                        Main Function
'*************************************************************************************************

								'/////////////////////

		strCommandName="get_computer_info.vbs"
		strDescription="Enumerate the needed windows host information."

		                        '/////////////////////
		
		ArgCount=2
		
		strArgMain(1)=			"-h"
		strArgSortDes(1)=		"hostname"
		strArgDetailDes(1)=		"	Host name"
		strArgExample(1)=		"Ser1"
		
		strArgMain(2)=			"-i"
		strArgSortDes(2)=		"information"
		strArgDetailDes(2)=		"	The needed information"
		strArgExample(2)=		"installed_services"
										
		strNameSpace = 	"root\cimv2"
		
	f_GetAllArg()
	f_Error()

  	if ((UCase(arg(0))="-H") Or (UCase(arg(0))="--HELP")) and (argcountcommand=1) then
		f_help()
  	else
  		if (f_TestLocalCommand()) then
  			strComputer=f_GetOneArg("-h")
  			if(strComputer = "localhost") then
  				strComputer = "."
  				Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
				Set colItems = objWMIService.ExecQuery("Select * from Win32_ComputerSystem",,48)
				For Each objItem in colItems
					strComputer = objItem.DNSHostName
				Next
			end if	
			strInfo=f_GetOneArg("-i")
			f_LocalPerfValue()
  			f_Error()
  		else
  			if (f_TestRemoteCommand()) then
  				strComputer=f_GetOneArg("-h")
				strInfo=f_GetOneArg("-i")
				strUser=f_GetOneArg("-user")
				strPass=f_GetOneArg("-pass")
				f_RemotePerfValue()
  				f_Error()
  			else
  				f_Error()
  				Wscript.echo "Error! Arguments are wrong."
  				Wscript.Quit(intError)
  			end if
  		end if
  	end if