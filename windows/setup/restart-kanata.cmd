@echo off
rem windows\setup\restart-kanata.cmd — (re)start kanata through its sign-in task.
rem Start-menu shortcut "Restart kanata" (hotkey Ctrl+Alt+F15 = Shift+Win+K via kanata) is created
rem by packages.cmd --apply kanata.  Wait 1 s first: when kanata itself sent the hotkey, killing it
rem while the keys are still down could leave Ctrl/Alt stuck.
ping -n 2 127.0.0.1 >nul
taskkill /f /im kanata_windows_gui_winIOv2_x64.exe >nul 2>&1
schtasks /run /tn dalekanium\kanata >nul
