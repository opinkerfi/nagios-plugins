@echo off

net stop NSClientpp

xcopy "%ProgramFiles%\NSclient++\*.ini" "%ProgramFiles%\NSclient++\backup\"  /i /h /y
xcopy \\10.100.1.170\nagios\nsclient\%PROCESSOR_ARCHITECTURE%\*.*  "%ProgramFiles%\NSclient++\" /e /i /h /y

"%ProgramFiles%\NSclient++\nsclient++.exe" -uninstall
"%ProgramFiles%\NSclient++\nsclient++.exe" -install
Net Start NSClientpp
