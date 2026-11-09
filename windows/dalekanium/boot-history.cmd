@echo off
rem windows\dalekanium\boot-history.cmd [days]
rem Boots, shutdowns, crashes, restarts and sleep/wake from the System event log (default: last 2 days).
rem   6005 boot (event log started)        6006 clean shutdown      6008 previous shutdown was unexpected
rem     41 rebooted without a clean shutdown (crash, hard hang, power loss)
rem   1074 a program or user asked for the shutdown/restart: names it (Windows Update shows up here)
rem     42 entering sleep                   107 resumed from sleep
rem Run from cmd, Git Bash (cmd //c boot-history.cmd 3) (no admin needed).
setlocal
set "DAYS=%~1"
if "%DAYS%"=="" set "DAYS=2"
powershell -NoProfile -Command ^
 "$s = (Get-Date).AddDays(-%DAYS%);" ^
 "'Last boot: {0:yyyy-MM-dd HH:mm:ss}' -f (Get-CimInstance Win32_OperatingSystem).LastBootUpTime; '';" ^
 "Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,42,107,1074,6005,6006,6008; StartTime=$s} -ErrorAction SilentlyContinue |" ^
 "Sort-Object TimeCreated |" ^
 "ForEach-Object { '{0:yyyy-MM-dd HH:mm:ss}  {1,5}  {2}' -f $_.TimeCreated, $_.Id, (($_.Message -split [Environment]::NewLine)[0]) }"
