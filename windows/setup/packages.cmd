@echo off
rem windows\setup\packages.cmd - run packages.sh from cmd (needs Git for Windows).
rem From an ELEVATED cmd:   packages.cmd            (dry run)
rem                         packages.cmd --apply [sections]
cd /d "%~dp0"
if not exist "%ProgramFiles%\Git\bin\bash.exe" (
  echo Git for Windows is missing: winget install -e --id Git.Git --scope machine
  exit /b 1
)
"%ProgramFiles%\Git\bin\bash.exe" packages.sh %*
