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
Const intWarning = 1
Const intCritical = 2
Const intError = 3
Const intUnknown = 3

Dim argcountcommand
Dim arg(20)
Dim strComputer
Dim strClass
Dim strProp
Dim strInst
Dim warningValue
Dim criticalValue
Dim strUser
Dim strPass
Dim strDomain
Dim strNameSpace
Dim strDescription
Dim strCommandName
Dim strResultTemp
Dim strResult1
Dim strResult2
Dim intReturnTemp
Dim intReturn
Dim strPrefix
Dim intValue
Dim returnValue
Dim instance
Dim instanceArray()
Dim instanceArraySize

Dim ArgCount
Dim strArgMain(10)
Dim strArgSortDes(10)
Dim strArgDetailDes(10)
Dim strArgExample(10)

Dim objWMIService, colWMI,objWMI,objSWbemLocator

strComputer=""
strClass = ""
strProp = ""
strInst = ""
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
	
		if (err.number <>0 ) then
			if err.number = -2147023174 then
				Wscript.echo "Critical - Timeout connecting to WMI on this host! Error Number: " & err.number & " Description: " & err.Description
				WScript.Quit(intCritical)
			else
				if err.number = -2147024891 then
					Wscript.echo "Authentication failure to remote host! Error Number: " & err.number & " Description: " & err.description
				else
					if err.number = 462 then
						Wscript.echo "Critical - Timeout connecting to WMI on this host! Error Number: " & err.number & " Description: " & err.Description
						WScript.Quit(intCritical)
					else 
						if err.number=-2147217392 then
							Wscript.echo "Error! Error Number: -2147217392 Description: Invalid Class"
						else	 
							Wscript.echo "Error! Error Number: " & err.number & " Description: " & err.description 
						end if	
					end if
				end if
			end if
			Wscript.Quit(intError)
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
  		str="Check State of a Service. If your Local Machine has the same Administrator account and password as the Remote Machine then you don't have to use the two last parameters."&vbCrlF&vbCrlF
  		str=str&"cscript check_services_states.vbs -h hostname -inst instancename [-user username -pass password [-domain domain]]"&vbCrlF
  		str=str&vbCrlF
  		str=str&"-h [--help]                 Help."&vbCrlF
  		str=str&"-h hostname                 Host name."&vbCrlF  
  		str=str&"-inst instance              Needed Instance."&vbCrlF  
  		str=str&"-user username              Account Administrator on Remote Machine."&vbCrlF
  		str=str&"-pass password              Password Account Administrator on Remote Machine."&vbCrlF
  		str=str&"-domain domain              Domain Name of Remote Machine."&vbCrlF
  		str=str&vbCrlF
  		str=str&"Note: information can be one or multiple services, or *." & vbCrlF
  		str=str&"And if get multiple services, the information must be enclosed in multiple quotes and separate by commas." & vbCrlF
  		str=str&"Example: cscript check_services_states.vbs -h Ser1 -inst ""WINS,wmi"" [-user SER1\Administrator -pass password] " & vbCrlF 
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
'Function Name:     f_GetOneInstance.
'Descripton:        Get infomation at Local Host.
'Input:				instance.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetOneInstance()
		
		On Error Resume Next
		
		if(instance = "*") then
			for Each objWMI In colWMI
				strOut = strOut & objWMI.Name & ": " & objWMI.State & "; "
			next
			strResultTemp = strOut
			Wscript.Echo strResultTemp
			Wscript.Quit(intOk)
			Exit Function
		else
			for Each objWMI In colWMI
				if(Ucase(instance) = Ucase(objWMI.Name)) then
					startMode=objWMI.StartMode
					if((startMode = "Disabled") or (startMode = "Manual")) then
						Wscript.Echo "OK - " & objWMI.Name & ": " & objWMI.State & " and " & startMode
						Wscript.Quit(intOk)
						Exit Function
					else
						if(objWMI.State = "Running") then
							Wscript.Echo "OK - " & objWMI.Name & ": " & objWMI.State
							Wscript.Quit(intOk)
							Exit Function
						else
							Wscript.Echo "Critical - " & objWMI.Name & ": " & objWMI.State
							Wscript.Quit(intCritical)
							Exit Function
						end if
					end if
				end if
			next
			Wscript.Echo "Unknown - " & instance & ": not installed"
			Wscript.Quit(intUnknown)
			Exit Function
		end if
										
	End Function
	
'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetMultiInstance.
'Descripton:        Get infomation at Local Host.
'Input:				instance.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetMultiInstance()
		
		On Error Resume Next
		
		strResultTemp = ""
		intResultTemp = 0
		
		for Each objWMI In colWMI
			if(Ucase(instance) = Ucase(objWMI.Name)) then
				startMode=objWMI.StartMode
				if((startMode = "Disabled") or (startMode = "Manual")) then
					strResultTemp = "OK - " & objWMI.Name & ": " & objWMI.State & " and " & startMode
					intReturnTemp = intOk
					Exit Function
				else
					if(objWMI.State = "Running" ) then
						strResultTemp = "OK - " & objWMI.Name & ": " & objWMI.State
						intReturnTemp = intOk
						Exit Function
					else
						strResultTemp = "Critical - " & objWMI.Name & ": " & objWMI.State
						intReturnTemp = intCritical
						Exit Function
					end if
				end if
			end if
		next
		strResultTemp = "Unknown - " & instance & ": not installed"
		intReturnTemp = intUnknown
		Exit Function
												
	End Function
	
'-------------------------------------------------------------------------------------------------
'Function Name:     f_ExecQuery.
'Descripton:        Execute query.
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_ExecQuery()
		
		On Error Resume Next
		
		strQuery = "Select "  & strProp & " from " & strClass
		Set colWMI = objWMIService.ExecQuery(strQuery)
		
		count = -1
		count = colWMI.count
		if(count = -1) then
			Wscript.Echo "Error! Invalid " & strProp & " property."
			Wscript.Quit(intError)
		end if
				
	End Function
	
'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetInstances.
'Descripton:        Get Prefix.
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetInstances()
		
		On Error Resume Next
		
		first = 1
		position = 0
		instanceArraySize = 0
		
    	position = InStr(first, strInst, ",")
    	if (position = 0) then
    		instanceTemp = strInst
    		InstanceArraySize = 1
    		ReDim instanceArray(instanceArraySize)
    		instanceArray(0) = instanceTemp
    		
    	else
          do while (position > 0)
            instanceTemp = Mid(strInst,first,position - first)
            instanceArraySize = instanceArraySize + 1
            ReDim Preserve instanceArray(instanceArraySize)
            instanceArray(instanceArraySize -1) = Trim(instanceTemp)
            first = position + 1
            position = InStr(first, strInst, ",")
          loop
          instanceTemp = Mid(strInst,first,len(strInst))
          instanceArraySize = instanceArraySize + 1
          ReDim Preserve instanceArray(instanceArraySize)
          instanceArray(instanceArraySize -1) = Trim(instanceTemp)
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
        
        strResult1 = ""
        strResult2 = ""
		intReturn = 0
		if(instanceArraySize = 1) then
			instance = instanceArray(0)
			f_GetOneInstance()
		else
        	for i  = 0 to instanceArraySize -1
				instance = instanceArray(i)
				f_GetMultiInstance()
				if intReturn < intReturnTemp then
			    	intReturn = intReturnTemp
			    end if
			    if(intReturnTemp > 0) then
			    	strResult2 = strResult2 & strResultTemp & "; "
			    else
			    	strResult1 = strResult1 & strResultTemp & "; "
			    end if
		    next
			Wscript.Echo strResult2 & strResult1
			Wscript.Quit(intReturn)
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
		
		Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\" & strNameSpace)
		f_Error()
		
		'Set colInstances = GetObject("winmgmts:{impersonationLevel=impersonate}\\" & strComputer & "\" & strNameSpace).InstancesOf(strClass)
		'For Each objInstance in colInstances
		'Next
		'f_Error()        
        f_ExecQuery()
        f_GetInstances()
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
			
			'Set colInstances = objSWbemLocator.ConnectServer(strComputer, strNamespace , strUser, strPass).InstancesOf(strClass)
			'For Each objInstance in colInstances
			'Next
			'f_Error()
		else
			Set objWMIService = objSWbemLocator.ConnectServer _
				(strComputer, strNameSpace , strUser, strPass,"MS_409","ntlmdomain:" + strDomain )
			f_Error()
			
			'Set colInstances = objSWbemLocator.ConnectServer(strComputer, strNamespace , strUser, strPass,"MS_409","ntlmdomain:" & strDomain ).InstancesOf(strClass)
			'For Each objInstance in colInstances
			'Next
			'f_Error()
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

		strCommandName="check_services_states.vbs"
		strDescription="Check state of one or multi services."

		                        '/////////////////////
											
		strNameSpace = 	"root\cimv2"
		strClass = "Win32_Service"
		strProp = "Name, State, StartMode"	
	f_GetAllArg()
	tempCount = argcountcommand/2
	f_Error()
	
  	if ((UCase(arg(0))="-H") Or (UCase(arg(0))="--HELP")) and (argcountcommand=1) then
		f_help()
  	else
  		if( ((argcountcommand Mod 2) = 0) and (1 < tempCount < 6)) then
  			strComputer = f_GetOneArg("-h")
  			strInst = f_GetOneArg("-inst")
  			strUser = f_GetOneArg("-user")
  			strPass = f_GetOneArg("-pass")
  			strDomain = f_GetOneArg("-domain")
  			if((strComputer = "") or (strInst = "")) then
  				Wscript.Echo "Error! Arguments wrong, require verify -h -inst parameters"
  				Wscript.Quit(intError)
  			else
  				Select Case tempCount
	  				Case 2:
	  					f_LocalPerfValue()
	  				Case 4:
	  					if ((strUser <> "") and (strPass <> "")) then
	  						f_RemotePerfValue()
	  					else
	  						Wscript.Echo "Error! Arguments wrong, please verify -user -pass parameters"
	  						Wscript.Quit(intError)	
	  					end if
	  				Case 5:
	  					if ((strUser <> "") and (strPass <> "") and (strDomain <> "")) then
	  						f_RemotePerfValue()
	  					else
	  						Wscript.Echo "Error! Arguments wrong for remote check, please verify -w -c -user -pass -domain parameters"
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