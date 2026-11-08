@echo off
rem windows\setup\restart-kanata.cmd — (re)start kanata through its sign-in task.
rem Start-menu shortcut "Restart kanata" is created by packages.cmd --apply kanata-user.
taskkill /f /im kanata_windows_gui_winIOv2_x64.exe >nul 2>&1
schtasks /run /tn dalekanium\kanata >nul
