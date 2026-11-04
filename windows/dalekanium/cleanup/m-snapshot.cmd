@echo off
rem windows\dalekanium\cleanup\m-snapshot.cmd - verbatim safety copy of M:\Eduardo, minus the synced
rem folders, onto the WD Elements (W:) BEFORE anything on M: is pruned. Copies only; deletes nothing.
rem Safe to re-run (copies only what changed). Run from a normal cmd:  m-snapshot.cmd
rem When it finishes cleanly it writes .snapshot-complete, which apply-manifest.sh requires.
set DEST=W:\M-Eduardo-snapshot-2026-11
if not exist W:\ ( echo W: [WD Elements] is not connected. & exit /b 1 )
robocopy M:\Eduardo "%DEST%" /E /XJ /COPY:DAT /DCOPY:DAT /R:1 /W:1 /MT:16 /NP /NFL /NDL /TEE /LOG+:"%DEST%.log" ^
  /XD M:\Eduardo\synchro M:\Eduardo\secreto M:\Eduardo\GoogleDrive M:\Eduardo\Dropbox M:\Eduardo\Tresorit M:\Eduardo\private
if %ERRORLEVEL% GEQ 8 ( echo FAILED: robocopy exit %ERRORLEVEL%, see %DEST%.log & exit /b 1 )
echo %DATE% %TIME% > "%DEST%\.snapshot-complete"
echo OK: snapshot in %DEST% (log %DEST%.log)
