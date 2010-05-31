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

Dim arg(20)
i = 0
strComputer = "."
strNamespace = "root\cimv2"
strClass="Win32_Service"
strProperty = ""
strUser = ""
strPass = ""

strNameList = ""
countertypeFound = 0

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


'*************************************************************************************************
'                                        Main Function
'*************************************************************************************************
On Error Resume Next
For i=0 to WScript.Arguments.Count-1
  arg(i)=WScript.Arguments( i )
Next


if (i=3) then
  strComputer=arg(0)
  strClass=arg(1)
  strProperty=arg(2)
else 
  if (i=5) then
    strComputer=arg(0)
    strClass=arg(1)
    strProperty=arg(2)
    strUser=arg(3)
    strPass=arg(4)
  else
    if (i=2) then
      strComputer=arg(0)
      strClass=arg(1)
    else
      if (i=4) then
        strComputer=arg(0)
        strClass=arg(1)
        strUser=arg(2)
        strPass=arg(3)
      else
        wscript.echo "Usage: get_counter_type.vbs <hostname> <class> [<property>] [<user> <password>]"
        wscript.quit(3)
      end if
    end if
  end if
end if


if (strUser <> "") then
  Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")	
  Set objWMIService = objSWbemLocator.ConnectServer _
    (strComputer, strNamespace , strUser, strPass )
  f_Error()
  Set objClass = objWMIService.Get(strClass)
  f_Error()
else
  set objWMIService = GetObject("winmgmts:\\" & strComputer & "\" & strNamespace)
  f_Error()
  set objClass = GetObject("winmgmts:\\" & strComputer & "\" & strNamespace & ":" & strClass)
end if
f_Error()

For Each objClassProperty In objClass.Properties_
      If (strProperty<>"") Then
        If objClassProperty.Name = strProperty Then
        	For Each objQualifier in ObjClassProperty.Qualifiers_
            	If objQualifier.Name = "countertype" Then
				countertypeFound = 1
				wscript.echo "Property " & objClassProperty.Name & " countertype = " & objQualifier.Value
      	      End If
        	Next
	  End If
      Else
		strNameList = strNameList & objClassProperty.Name & " "
      End If
Next

if (strProperty="") then
  wscript.echo strNameList
else
  if (countertypeFound=0) then
    wscript.echo "Property " & strProperty & " does not have a defined countertype."
  end if
end if