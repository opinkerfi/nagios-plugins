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
Dim warningValueString
Dim criticalValue
Dim criticalValueString
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
Dim returnValue
Dim strPropBase
Dim strNameTemp
Dim strPropNameTemp
Dim counterValueArray()
Dim timerValueTempArray()
Dim strNameArray()
Dim intValueArray()
Dim strPropName
Dim instanceArray()
Dim instanceArraySize
Dim warningArraySize
Dim criticalArraySize
Dim warningArray()
Dim criticalArray()
Dim instance
Dim propArray()
Dim propArraySize
Dim lWarningValue
Dim uWarningValue
Dim lCriticalValue
Dim uCriticalValue

Dim ArgCount
Dim strArgMain(10)
Dim strArgSortDes(10)
Dim strArgDetailDes(10)
Dim strArgExample(10)

Dim objWMIService, colWMI, colWMITemp, objWMI, objSWbemLocator

strComputer=""
strClass = ""
strProp = ""
strInst = ""
warningValue = -1
criticalValue = -1
strUser = ""
strPass = ""
strDomain = ""

intReturnTemp1 = 0
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
  		str="Check 100NSEC TIMER. If your Local Machine has the same Administrator account and password as the Remote Machine then you don't have to use the two last parameters."&vbCrlF&vbCrlF
  		str=str&"cscript check_100nsec_timer.vbs -h hostname -class classname -prop property -inst instancename [-w warning_level -c critical_level] [-user username -pass password [-domain domain]]"&vbCrlF
  		str=str&vbCrlF
  		str=str&"-h [--help]                 Help."&vbCrlF
  		str=str&"-h hostname                 Host name."&vbCrlF  
  		str=str&"-class classname            Class name."&vbCrlF
  		str=str&"-prop property              Property of Class."&vbCrlF  
  		str=str&"-inst instance              Needed Instance, can be * for all"&vbCrlF  
  		str=str&"-w warning_level            Warning threshold."&vbCrlF
  		str=str&"-c critical_level           Critical threshold."&vbCrlF
  		str=str&"-user username              Account Administrator on Remote Machine."&vbCrlF
  		str=str&"-pass password              Password Account Administrator on Remote Machine."&vbCrlF
  		str=str&"-domain domain              Domain Name of Remote Machine."&vbCrlF
  		str=str&vbCrlF
  		str=str&"Example: cscript check_100nsec_timer.vbs -h Ser1 -class Win32_PerfRawData_PerfOS_Processor -prop PercentUserTime -inst ""*"" -w 30 -c 70 [-user Ser1\Administrator -pass password -domain ITSP] "&vbCrlF
  		str=str&"Example: cscript check_100nsec_timer.vbs -h Ser1 -class Win32_PerfRawData_PerfOS_Processor -prop PercentUserTime -inst ""Name = '0'"" -w 30 -c 70 [-user Ser1\Administrator -pass password -domain ITSP] "
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
'Function Name:     f_GetInstance.
'Descripton:        Get infomation at Local Host.
'Input:				instance.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetInstance(instance)
		
		On Error Resume Next
		
		strResultTemp1 = ""
		strResultTemp2 = ""
		strResultTemp = ""
		intResultTemp = 0
		strPropBase = ""

		strInstanceTemp1 = ""
		strInstanceTemp2 = ""
		intInstanceTemp1 = 0
		intInstanceTemp2 = 0

		'Depend on strInfo parameters to get the result value
		if(instance = "*") then
			strQuery = "Select " & strProp & ", TimeStamp_Sys100NS" & " from " & strClass
			Set colWMITemp = objWMIService.ExecQuery(strQuery)
			Wscript.Sleep(1000)
			Set colWMI = objWMIService.ExecQuery(strQuery)
		else
		
		'Depend on strInfo parameters to get the result value

			intInstanceTemp1 = InStr(1,instance,"=")
			strInstanceTemp1 = Mid(instance,1,intInstanceTemp1-1)
			intInstanceTemp2 = Len(instance)
			strInstanceTemp2 = Mid(instance,intInstanceTemp1+1,intInstanceTemp2-intInstanceTemp1)
			instance=strInstanceTemp1 & "='" & strInstanceTemp2 & "'"

			strQuery = "Select " & strProp & ", TimeStamp_Sys100NS" & " from " & strClass & " where " & instance
			Set colWMITemp = objWMIService.ExecQuery(strQuery)
			Wscript.Sleep(1000)
			Set colWMI = objWMIService.ExecQuery(strQuery)
		end if
		
		count = -1
		count = colWMI.count
		if(count = -1) then
			Wscript.Echo "Unknown - No data received from WMI;"
			Wscript.Quit(intUnknown)
		else 
			if(colWMI.count > 0) then
				f_GetData()
				strResultTemp1 = strResultTemp1 & strResultTemp3
				strResultTemp2 = strResultTemp2 & strResultTemp4
				intReturnTemp = intReturnTemp1
				Exit Function
			else
				strResultTemp1 = "Unknown - " & instance &" query: No row returned."
				intReturnTemp = intUnknown
				Exit Function
			end if
		end if								
	End Function
	
'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetPrefix.
'Descripton:        Get Prefix.
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetPrefix(intValue)
		
		On Error Resume Next
		
		strPrefix = ""
		If(warningValue <> "" And criticalValue = "") Then 
			If (IsNumeric(warningValue)) Then 
				If (Int(intValue) < Int(warningValue)) Then
					returnValue=0
					strPrefix= "OK - "
				Else
					returnValue=1
					strPrefix= "Warning - "
				End If 
			Else
				Wscript.Echo "Error! Arguments wrong, please verify -w parameter"
				Wscript.Quit(intError)
				Exit Function
			End If 
		End If 
		If(warningValue = "" And criticalValue <> "") Then 
			If (IsNumeric(criticalValue)) Then 
				If (Int(intValue) < Int(criticalValue)) Then
					returnValue=0
					strPrefix= "OK - "
				Else
					returnValue=2
					strPrefix= "Critical - "
				End If 
			Else
				Wscript.Echo "Error! Arguments wrong, please verify -c parameter"
				Wscript.Quit(intError)
				Exit Function
			End If 
		End If 
		If (warningValue <> "" And criticalValue <> "") Then 
			If (IsNumeric(warningValue) And IsNumeric(criticalValue)) Then
				if (Int(warningValue) < Int(criticalValue)) then
		      
		            if (Int(intValue) < Int(warningValue)) then
		                returnValue=0
		                strPrefix= "OK - "
		            else
		                if (Int(intValue) < Int(criticalValue)) then
		                    returnValue=1
		                    strPrefix= "Warning - "
		                else
		                    returnValue=2
		                    strPrefix= "Critical - "
		                end if
		            end if
		        else
		            if (Int(intValue) > Int(warningValue)) then
		                returnValue=0
		                strPrefix= "OK - "
		            else
		                if (Int(intValue) > Int(criticalValue)) then
		                    returnValue=1
		                    strPrefix= "Warning - "
		                else
		                    returnValue=2
		                    strPrefix= "Critical - "
		                end if
		            end if
		        end If
	        Else
	        	Wscript.Echo "Error! Arguments wrong, please verify -w -c parameter"
				Wscript.Quit(intError)
				Exit Function
	        End If 
        End If 

	End Function
	
'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetPrefixWithRange.
'Descripton:        Get Prefix.
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetPrefixWithRange(intValue)
		
        On Error Resume Next
        lWarningValue = ""
	    uWarningValue = ""
	    lCriticalValue= ""
	    uCriticalValue= ""
	    warningReturn = 0
	    criticalReturn = 0
	    If(warningValue <> "") Then 
	    	f_GetWarningValueFromRange(warningValue)
	    End If
	    If(criticalValue <> "") Then 
	    	f_GetCriticalValueFromRange(criticalValue)
	    End If
	    strPrefix = ""
	  	'verify warning
	    If((lWarningValue <> "") And (uWarningValue <> "")) Then
	    	If(Int(lWarningValue) <= Int(uWarningValue)) Then
	  	    	If((Int(lWarningValue) >= Int(intValue)) Or (Int(intValue) >= Int(uWarningValue))) Then
		        	warningReturn=1
                End If 
		    Else
		        If((Int(intValue) >= Int(uWarningValue) ) And (Int(intValue) <= Int(lWarningValue))) Then
		        	warningReturn=1
                End If 
		    End If
	    End If
	    If((lWarningValue <> "") And (uWarningValue = "")) Then 
	        If(Int(intValue) <= Int(lWarningValue)) Then 
                warningReturn=1
            End If
	    End If 
	    If((lWarningValue = "") And (uWarningValue <> "")) Then 
	  	    If(Int(intValue) >= Int(uWarningValue)) Then 
                warningReturn=1
            End If
	    End If
	    
	    'verify critical
	    If((lCriticalValue <> "") And (uCriticalValue <> "")) Then
	        If(Int(lCriticalValue) <= Int(uCriticalValue)) Then
		        If((Int(lCriticalValue) >= Int(intValue)) Or (Int(intValue) >= Int(uCriticalValue))) Then
		            criticalReturn=2
                End If 
		    Else
		        If((Int(intValue) >= Int(uCriticalValue) ) And (Int(intValue) <= Int(lCriticalValue))) Then
			        criticalReturn=2
                End If 
		    End If
	    End If
	    If((lCriticalValue <> "") And (uCriticalValue = "")) Then 
	        If(Int(intValue) <= Int(lCriticalValue)) Then 
                criticalReturn=2
            End If
	    End If 
	    If((lCriticalValue = "") And (uCriticalValue <> "")) Then 
	        If(Int(intValue) >= Int(uCriticalValue)) Then 
                criticalReturn=2
            End If
	    End If
      
	    'return result
	    If(criticalReturn = 2) Then 
	        returnValue=2
		    strPrefix= "Critical - "
	    Else 
	        If(warningReturn = 1) Then 
		        returnValue=1
		        strPrefix= "Warning - "
		    Else
			    returnValue=0
		        strPrefix= "Ok - "
		    End If
	    End If

    End Function

'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetWarningValueFromRange().
'Descripton:        Get perform value at Local Host.
'Input:				warningValueRange.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetWarningValueFromRange(warningValue)
		
		On Error Resume Next
		lWarningValue = ""
	    uWarningValue = ""
		temp1 = 0
		temp1 = InStr(1, warningValue, ":")
		if(temp1 > 0) then
			lWarningTemp = Mid(warningValue, 1, temp1 -1)
			uWarningTemp = Mid(warningValue, temp1 +1, len(warningValue) - temp1)
			if(IsNumeric(lWarningTemp) or IsNumeric(uWarningTemp)) then
				lWarningValue = lWarningTemp
				uWarningValue = uWarningTemp
			else
				Wscript.Echo "Error! Arguments wrong, please verify -w parameter"
				Wscript.Quit(intError)
				Exit Function
			end if
		else
			Wscript.Echo "Error! Arguments wrong, please verify -w parameter"
			Wscript.Quit(intError)
			Exit Function
		end if

	End Function
		 
'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetCriticalValueFromRange().
'Descripton:        Get perform value at Local Host.
'Input:				warningValueRange.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetCriticalValueFromRange(criticalValue)
		
		On Error Resume Next
		lCriticalValue = ""
	    uCriticalValue = ""
		temp1 = 0
		temp1 = InStr(1, criticalValue, ":")
		if(temp1 > 0) then
			lCriticalTemp = Mid(criticalValue, 1, temp1 -1)
			uCriticalTemp = Mid(criticalValue, temp1 +1, len(criticalValue) - temp1)
			if(IsNumeric(lCriticalTemp) or IsNumeric(uCriticalTemp)) then
				lCriticalValue = lCriticalTemp
				uCriticalValue = uCriticalTemp
			else
				Wscript.Echo "Error! Arguments wrong, please verify -c parameter"
				Wscript.Quit(intError)
				Exit Function
			end if
		else
			WScript.Echo "Error! Arguments wrong, please verify -c parameter"
			Wscript.Quit(intError)
			Exit Function
		end if

	End Function
	
'-------------------------------------------------------------------------------------------------
'Function Name:     f_GetData.
'Descripton:        Format data the same as output.
'Input:				no.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetData()
		
		On Error Resume Next
		
		ReDim strNameArray(Int(colWMI.count))
		ReDim counterValueArray(Int(colWMI.count))
		ReDim timerValueArray(Int(colWMI.count))
		ReDim intValueArray(Int(colWMI.count))
		
		strDisplay1 = ""
		strDisplay2 = ""
		strResultTemp3 = ""
		strResultTemp4 = ""
		'strResultTemp1 = ""
		
		strNameTemp = ""
		strPropNameTemp = ""
		counterValueTemp = 0
		timerValueTemp = 0
		timeBaseTemp = 0
		i, j = 0
		 
		For Each objWMITemp in colWMITemp
			counterValueArray(i) = objWMITemp.Properties_(strProp)
			timerValueArray(i) = objWMITemp.Properties_("TimeStamp_Sys100NS")
			i = i + 1
		Next

		For Each objWMI in colWMI
			strNameTemp = objWMI.Name
			strPropNameTemp = objWMI.Properties_(strProp).Name
			counterValueTemp = objWMI.Properties_(strProp)
			timerValueTemp = objWMI.Properties_("TimeStamp_Sys100NS")
			strNameArray(j) = strNameTemp
			if((timerValueTemp - timerValueArray(j)) = 0) then
				intValueArray(j) = 0
			else	
				intValueArray(j) = (100 * (counterValueTemp - counterValueArray(j))) / (timerValueTemp - timerValueArray(j))
			end if
			j = j + 1
		Next
		
		for k = 0 to (Int(colWMI.count) - 1)
			strName = strNameArray(k)
			Dim strDSName
			strDSName = f_FormatDSName(strName)
			strPropName = strPropNameTemp
			intValue = (intValueArray(k))
			if((warningValue <> "") or (criticalValue <> "")) then
				strDisplay1 = strName & " '" & strPropName & "'" & " = " & intValue & "; "
				strDisplay2 =  "'" & strDSName  & "'" & "=" & intValue & ";" & warningValue & ";" & criticalValue & ";; "
				If(InStr(1, warningValue, ":") > 0 Or InStr(1, criticalValue, ":") > 0) Then
					f_GetPrefixWithRange(intValue)
				Else 
				    f_GetPrefix(intValue)
				End If
				strResultTemp3 = strResultTemp3 & strPrefix & strDisplay1
				strResultTemp4 = strResultTemp4 & strDisplay2
				if( intReturnTemp1 < returnValue) then
					intReturnTemp1 = returnValue
				end if
			else
				strResultTemp3 = strResultTemp3 & "OK - " & strName & " '" & strPropName & "'" & " = " & intValue & "; "
				strResultTemp4 = ""
			end if
		next					
	End Function	

'-------------------------------------------------------------------------------------------------
'Function Name:     f_FormatDSName.
'Descripton:        Get infomation at Local Host.
'Input:				strName.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_FormatDSName(strName)
			
		On Error Resume Next
		
		first = 1
		position1 = 0
		
		position1 = InStr(first, strName, "=")
		Dim proc_name
		proc_name = ""
		If(position1 > 0) Then 
			proc_name = Mid(strName,position1+1,(Len(strName)-position1))
			proc_name = Replace(proc_name,".","_")
			proc_name = Replace(proc_name,"-","_")
			proc_name = Mid(proc_name,1, 19)
			
			
		Else
			proc_name = Mid(strName,position1+1,(Len(strName)-position1))
			proc_name = Replace(proc_name,".","_")
			proc_name = Replace(proc_name,"-","_")
			proc_name = Mid(proc_name,1, 19)
			
		End If 
		f_FormatDSName = proc_name
		Exit Function
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
		strResult1 = ""
        strResult2 = ""
		intReturn = 0
		instance = strInst
		first=1
        tam1=10
        tam = -1
        
        If(instanceArraySize > 0 and (warningArraySize > 1 Or criticalArraySize > 1)) Then
        	for i  = 0 to instanceArraySize -1
				instance = instanceArray(i)
				warningValue = warningArray(i)
				criticalValue = criticalArray(i)
				f_GetInstance(instance)
				strResult1 = strResult1 & strResultTemp1
				strResult2 = strResult2 & strResultTemp2
		      	if intReturn < intReturnTemp then
		      		intReturn = intReturnTemp
		      	end if
			Next
        Else
        	for i  = 0 to instanceArraySize -1
				instance = instanceArray(i)
				f_GetInstance(instance)
				strResult1 = strResult1 & strResultTemp1
				strResult2 = strResult2 & strResultTemp2
		      	if intReturn < intReturnTemp then
		      		intReturn = intReturnTemp
		      	end if
			Next
        end if
		if(strResult2 = "") then
        	strResult = strResult1
        else
        strResult = strResult1 & "|" & strResult2
        end if
		Wscript.Echo strResult
		Wscript.Quit(intReturn)
		
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
'Function Name:     f_GetWarningCriticalValues.
'Descripton:        Get Prefix.
'Input:				No.
'Output:			No.
'-------------------------------------------------------------------------------------------------
	Function f_GetWarningCriticalValues()
		
		On Error Resume Next
		
		position1 = 0
		position2 = 0
		position3 = 0
		position4 = 0
		temp1 = 1
		temp2 = 1
		warningArraySize = 0
		criticalArraySize = 0
		
		'get warning
    	position2 = InStr(temp1, warningValueString, ",")
    	If(position2 = 0) then
			position2 = Len(warningValueString)+1
	    end if
	    
	    If(position2 > position1) then
		    do while (position2 > position1)
		        warningPair = Mid(warningValueString, position1 + 1, (position2 - position1 -1))
		        warningArraySize = warningArraySize + 1
			    ReDim Preserve warningArray(warningArraySize)
			    warningArray(warningArraySize -1) = Trim(warningPair)
			    temp1 = position2 + 1
		        position1 = position2
	    	    position2 = InStr(temp1, warningValueString, ",")
			    If(position2 = 0) then
			        position2 = Len(warningValueString)+1
			    End If
		    loop
	    end If
	    
	    If(Int(warningArraySize) < Int(instanceArraySize)) Then 
	        ReDim Preserve warningArray(instanceArraySize)
	        For i = 0 To (instanceArraySize - warningArraySize - 1)
	            warningArray(warningArraySize +i) = warningArray(warningArraySize-1)
	        Next
	        warningArraySize = instanceArraySize
	    End If
	    'get critical
	    position4 = InStr(temp2, criticalValueString, ",")
    	If(position4 = 0) then
			position4 = Len(criticalValueString)+1
	    end if
	    
	    If(position4 > position3) then
		    do while (position4 > position3)
		        criticalPair = Mid(criticalValueString, position3 + 1, (position4 - position3 -1))
		        criticalArraySize = criticalArraySize + 1
			    ReDim Preserve criticalArray(criticalArraySize)
			    criticalArray(criticalArraySize -1) = Trim(criticalPair)
			    temp2 = position4 + 1
		        position3 = position4
	    	    position4 = InStr(temp2, criticalValueString, ",")
			    If(position4 = 0) then
			        position4 = Len(criticalValueString)+1
			    End If
		    loop
	    End If
	    If(Int(criticalArraySize) < Int(instanceArraySize)) Then 
	        ReDim Preserve criticalArray(instanceArraySize)
	        For i = 0 To (instanceArraySize - criticalArraySize - 1)
	            criticalArray(criticalArraySize +i) = criticalArray(criticalArraySize-1)
	        Next
	        criticalArraySize = instanceArraySize
	    End If
	    
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
		
        f_GetInformation()

	End Function
	
'*************************************************************************************************
'                                        Main Function
'*************************************************************************************************

								'/////////////////////

		strCommandName="check_counter_bulk_count.vbs"
		strDescription="Enumerate the needed windows host information."

		                        '/////////////////////
											
		strNameSpace = 	"root\cimv2"
		
	f_GetAllArg()
	tempCount = argcountcommand/2
	f_Error()
	strClass = ""
	
  	if ((UCase(arg(0))="-H") Or (UCase(arg(0))="--HELP")) and (argcountcommand=1) then
		f_help()
  	else
  		if( ((argcountcommand Mod 2) = 0) and (3 < tempCount < 11)) then
  			strComputer = f_GetOneArg("-h")
  			strClass = f_GetOneArg("-class")
  			strProp = f_GetOneArg("-prop")
  			strInst = f_GetOneArg("-inst")
  			f_GetInstances()
  			warningValue = f_GetOneArg("-w")
			warningValueString = f_GetOneArg("-w")
  			criticalValue = f_GetOneArg("-c")
			criticalValueString = f_GetOneArg("-c")
			If((warningValueString <> "") Or (criticalValueString <> "")) Then 
  				f_GetWarningCriticalValues()
  			End if
  			strUser = f_GetOneArg("-user")
  			strPass = f_GetOneArg("-pass")
  			strDomain = f_GetOneArg("-domain")
  			if((strComputer = "") or (strClass = "") or (strProp = "") or (strInst = "")) then
  				Wscript.Echo "Error! Arguments wrong, require verify -h -class -prop -inst parameters"
  				Wscript.Quit(intError)
  			else
  				Select Case tempCount
	  				Case 4:
	  					f_LocalPerfValue()
	  				Case 6:
	  					if ((warningValue <> "") and (criticalValue <> "")) then
	  						f_LocalPerfValue()
	  					end if	
	  					if ((strUser <> "") and (strPass <> "")) then
	  						f_RemotePerfValue()
	  					else
	  						Wscript.Echo "Error! Arguments wrong, please verify -user -pass or -w -c parameters"
	  						Wscript.Quit(intError)	
	  					end if
	  				Case 8:
	  					if ((strUser <> "") and (strPass <> "") and (warningValue <> "") and (criticalValue <> "")) then
	  						f_RemotePerfValue()
	  					else
	  						Wscript.Echo "Error! Arguments wrong for remote check, please verify -w -c -user -pass parameters"
	  						Wscript.Quit(intError)
	  					end if
	  				Case 9:
	  					if ((strUser <> "") and (strPass <> "") and (warningValue <> "") and (criticalValue <> "") and (strDomain <> "")) then
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