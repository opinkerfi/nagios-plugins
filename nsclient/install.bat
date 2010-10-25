@echo off

net stop NSClientpp

xcopy "%ProgramFiles%\NSclient++\*.ini" "%ProgramFiles%\NSclient++\backup\"  /i /h /y 
xcopy .\trunk\*.*  "%ProgramFiles%\NSclient++\" /e /i /h /y 

"%ProgramFiles%\NSclient++\nsclient++.exe" -uninstall
"%ProgramFiles%\NSclient++\nsclient++.exe" -install


echo "-------- INSTALL COMPLETED --------------"
echo "Remember to notepad %ProgramFiles%\NSclient++\check_eva.ini before completing install"
pause

Net Start NSClientpp
