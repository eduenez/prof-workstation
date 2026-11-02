@echo off
rem windows\setup\configure.cmd - run configure.sh from cmd (needs Git for Windows).
rem From an ELEVATED cmd:   configure.cmd            (dry run)
rem                         configure.cmd --apply
cd /d "%~dp0"
if not exist "%ProgramFiles%\Git\bin\bash.exe" (
  echo Git for Windows is missing: winget install -e --id Git.Git --scope machine
  exit /b 1
)
"%ProgramFiles%\Git\bin\bash.exe" configure.sh %*
