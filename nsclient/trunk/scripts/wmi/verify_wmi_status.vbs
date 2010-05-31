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
Const intCritical = 2
Const intError = 3
Const intUnknown = 3

Dim argcountcommand
Dim arg(20)
Dim strComputer
Dim strClass
Dim strProp
Dim strUser
Dim strPass
Dim strDomain
Dim strNameSpace
Dim strDescription
Dim strCommandName
Dim strResultTemp
Dim strResult
Dim strResult1
Dim strResult2
Dim intReturnTemp
Dim intReturn
Dim strResultTemp1
Dim strResultTemp2
Dim strResultTemp3
Dim strResultTemp4
Dim intReturnTemp1
Dim strPrefix
Dim intValue
Dim returnValue
Dim instanceArray()
Dim instanceArraySize
Dim thresoldArraySize
Dim instance

Dim strDisplay1
Dim strDisplay2
Dim strName
Dim strPropName
Dim intAverageValue

Dim ArgCount
Dim strArgMain(10)
Dim strArgSortDes(10)
Dim strArgDetailDes(10)
Dim strArgExample(10)

Dim objWMIService, colWMI,objWMI,objSWbemLocator

strComputer=""
strClass = ""
strProp = ""
strUser = ""
strPass = ""
strDomain = ""
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
	
		Dim str
  		str="Verify connection to target host via WMI. If your Local Machine has the same Administrator account and password as the Remote Machine then you don't have to use the two last parameters."&vbCrlF&vbCrlF
  		str=str&"cscript verify_wmi_status.vbs -h hostname [-user username -pass password [-domain domain]]"&vbCrlF
  		str=str&vbCrlF
  		str=str&"-h [--help]                 Help."&vbCrlF
  		str=str&"-h hostname                 Host name."&vbCrlF  
  		str=str&"-user username              Account Administrator on Remote Machine."&vbCrlF
  		str=str&"-pass password              Password Account Administrator on Remote Machine."&vbCrlF
  		str=str&"-domain domain              Domain Name of Remote Machine."&vbCrlF
  		str=str&vbCrlF
  		str=str&"Example: cscript verify_wmi_status.vbs -h Ser1 [-user Ser1\Administrator -pass password -domain ITSP] " &vbCrlF
  		wscript.echo str
		
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
'Function Name:     f_ExecQuery.
'Descripton:        Format data the same as output.
'Input:				service.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_ExecQuery()
		
		On Error Resume Next
		
		strQuery = "Select " & strProp & " from " & strClass
		Set colWMI = objWMIService.ExecQuery(strQuery)
		count = -1
		count = colWMI.count
		if(count = -1) then
			Wscript.Echo "Error! Invalid " & strProp & " properties."
			Wscript.Quit(intError)
		end if
	
	End Function
	        
'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetInformation.
'Descripton:        Get information data.
'Input:				No.
'Output:			Values.
'-------------------------------------------------------------------------------------------------
	Function f_GetInformation()
        
        On Error Resume Next
        
        strResult = ""
	  intReturn = 0

	  for Each objInstance in colWMI
		strResult = strResult & "" & objInstance.Caption & ", SP " & objInstance.ServicePackMajorVersion & "." & objInstance.ServicePackMinorVersion
	  Next
	  strResult = "OK - " & strResult
        Wscript.Echo strResult
		Wscript.Quit(intReturn)
		
	End Function
	

'-------------------------------------------------------------------------------------------------
'Function Name:     f_LocalPerfValue.
'Descripton:        Get perform value at Local Host.
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_LocalPerfValue()
		
		On Error Resume Next
		
		Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\" & strNameSpace)
		f_Error()
		Set colInstances = GetObject("winmgmts:{impersonationLevel=impersonate}\\" & strComputer & "\" & strNameSpace).InstancesOf(strClass)
		For Each objInstance in colInstances
		Next
		f_Error()
		        
        f_ExecQuery()
        f_GetInformation()	

	End Function
		    
'-------------------------------------------------------------------------------------------------
'Function Name:     f_RemotePerfValue.
'Descripton:        Get perform values at Remote Host.
'Input:				No.
'Output:			Values.
'-------------------------------------------------------------------------------------------------
	Function f_RemotePerfValue()
		
		On Error Resume Next
		        
        Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")
		if (strDomain = "") then
			Set objWMIService = objSWbemLocator.ConnectServer _
				(strComputer, strNameSpace , strUser, strPass )	
			f_Error()
			
			Set colInstances = objSWbemLocator.ConnectServer(strComputer, strNamespace , strUser, strPass).InstancesOf(strClass)
			For Each objInstance in colInstances
			Next
			f_Error()
		else
			Set objWMIService = objSWbemLocator.ConnectServer _
				(strComputer, strNameSpace , strUser, strPass,"MS_409","ntlmdomain:" + strDomain )
			f_Error()
			
			Set colInstances = objSWbemLocator.ConnectServer(strComputer, strNamespace , strUser, strPass,"MS_409","ntlmdomain:" & strDomain ).InstancesOf(strClass)
			For Each objInstance in colInstances
			Next
			f_Error()
		end if
		objWMIService.Security_.ImpersonationLevel = 3
		f_Error()
		
	  f_ExecQuery()
        f_GetInstances()
        f_GetInformation()

	End Function
	
'*************************************************************************************************
'                                        Main Function
'*************************************************************************************************

								'/////////////////////

		strCommandName="verify_wmi_status.vbs"
		strDescription="Verify target host WMI status."

		                        '/////////////////////
											
		strNameSpace = 	"root\cimv2"
		strClass = "Win32_OperatingSystem"
		strProp = "Caption,ServicePackMajorVersion,ServicePackMinorVersion"
	f_GetAllArg()
	tempCount = argcountcommand/2
	f_Error()
	
  	if ((UCase(arg(0))="-H") Or (UCase(arg(0))="--HELP")) and (argcountcommand=1) then
		f_help()
  	else
  		if( ((argcountcommand Mod 2) = 0) and (1 < tempCount < 5)) then
  			strComputer = f_GetOneArg("-h")
  			strUser = f_GetOneArg("-user")
  			strPass = f_GetOneArg("-pass")
  			strDomain = f_GetOneArg("-domain")
  			if((strComputer = "")) then
  				Wscript.Echo "Error! Arguments wrong, require verify -h parameter"
  				Wscript.Quit(intError)
  			else
  				Select Case tempCount
	  				Case 1:
	  					f_LocalPerfValue()
	  				Case 3:
	  					if ((strUser <> "") and (strPass <> "")) then
	  						f_RemotePerfValue()
	  					else
	  						Wscript.Echo "Error! Arguments wrong, please verify -user -pass parameters"
	  						Wscript.Quit(intError)	
	  					end if
	  				Case 4:
	  					if ((strUser <> "") and (strPass <> "") and (strDomain <> "")) then
	  						f_RemotePerfValue()
	  					else
	  						Wscript.Echo "Error! Arguments wrong, please verify -user -pass -domain parameters"
	  						Wscript.Quit(intError)
	  					end if
	  				Case Else
	  					Wscript.Echo "Error! Arguments wrong, please type -h for Help"
	  					Wscript.Quit(intError)
  				End Select
  						
  			end if
  		else
  			Wscript.Echo "Error! Arguments wrong, please type -h for Help"
  			Wscript.Quit(intError)
  		end if  
  		
  	end if