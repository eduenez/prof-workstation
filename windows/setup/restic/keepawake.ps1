# windows/setup/restic/keepawake.ps1 — keeps Windows from sleeping while process ParentPid runs.
# Started by restic.sh nightly; ES_CONTINUOUS|ES_SYSTEM_REQUIRED, released when this exits.
# When the PC was woken by the task, Windows lets it sleep again ~2 min after this ends (no user input).
param([Parameter(Mandatory)][int]$ParentPid)
Add-Type -Namespace DK -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);'
[DK.Power]::SetThreadExecutionState([uint32]"0x80000001") | Out-Null
try { Wait-Process -Id $ParentPid -ErrorAction SilentlyContinue } finally { [DK.Power]::SetThreadExecutionState([uint32]"0x80000000") | Out-Null }
