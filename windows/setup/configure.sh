#!/usr/bin/env bash
# windows/setup/configure.sh — Phase 5 of windows/dalekanium/PLAN.md:
# Windows 11 settings, policies and registry, applied deterministically.
#
# Run from an ELEVATED cmd (Eduardo's account is an admin, so HKCU below is still his own hive):
#   M:\Eduardo\repos\prof-workstation\windows\setup\configure.cmd            (dry run)
#   M:\Eduardo\repos\prof-workstation\windows\setup\configure.cmd --apply
#   ...configure.cmd --apply edge defaults        (only some sections)
# or from "Git Bash (admin)":  bash configure.sh [--apply] [sections]
# Sections: name update privacy edge defaults lockscreen shell input folders power terminal
# Idempotent: re-running re-applies the same values. Sign out and back in afterwards
# (the computer rename needs a restart).
#
# Many "policy" keys below only take effect on Pro/Enterprise; a few are honoured only on
# Enterprise/Education and are harmless no-ops on Pro (marked "Ent").

set -u
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'   # Git Bash must not rewrite /flags or C:\ paths

APPLY=false
[[ ${1:-} == --apply ]] && { APPLY=true; shift; }
SECTIONS=${*:-"name update privacy edge defaults lockscreen shell input folders power terminal"}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FAILS=0

if ! net.exe session >/dev/null 2>&1; then
    echo "Run this from an elevated (Run as administrator) cmd or Git Bash." >&2; exit 1
fi
$APPLY || echo "DRY RUN — nothing will change. Re-run with --apply."

LOGDIR=/c/ProgramData/dalekanium/logs
LOG="$LOGDIR/configure-$(date +%Y%m%d-%H%M%S).log"
FAILED=()
$APPLY && { mkdir -p "$LOGDIR"; echo "Logging to $(cygpath -w "$LOG" 2>/dev/null || echo "$LOG")"; }
run() {   # run CMD...: print, and execute when --apply; output and errors go to $LOG
    printf '  %s\n' "$*"
    $APPLY || return 0
    { printf '\n$ %s\n' "$*"; } >>"$LOG"
    "$@" >>"$LOG" 2>&1; local rc=$?
    if (( rc != 0 )); then
        echo "    !! failed (exit $rc) — details in the log"
        echo "!! FAILED" >>"$LOG"
        FAILS=$((FAILS+1)); FAILED+=("$*")
    fi
}
reg_dword() { run reg.exe add "$1" /v "$2" /t REG_DWORD /d "$3" /f; }
reg_sz()    { run reg.exe add "$1" /v "$2" /t REG_SZ /d "$3" /f; }
reg_xsz()   { run reg.exe add "$1" /v "$2" /t REG_EXPAND_SZ /d "$3" /f; }
want() { [[ " $SECTIONS " == *" $1 "* ]]; }
hdr()  { printf '\n== %s\n' "$*"; }

HKLMP='HKLM\SOFTWARE\Policies\Microsoft'
HKCUP='HKCU\Software\Policies\Microsoft'
ADV='HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
CDM='HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

# ── computer name ──────────────────────────────────────────────────────
if want name; then
    hdr "computer name -> DALEKANIUM (setup left a random DESKTOP-xxxx name)"
    if [[ ${COMPUTERNAME:-} != DALEKANIUM ]]; then
        run powershell.exe -NoProfile -NonInteractive -Command "Rename-Computer -NewName DALEKANIUM -Force"
        echo "  (takes effect after a restart)"
    else echo "  already DALEKANIUM"; fi
fi

# ── Windows Update: you decide when ────────────────────────────────────
if want update; then
    hdr "Windows Update: nothing downloads or installs without you; no restart while signed in; drivers yes, firmware/BIOS never"
    reg_dword "$HKLMP\Windows\WindowsUpdate\AU" NoAutoUpdate 0
    reg_dword "$HKLMP\Windows\WindowsUpdate\AU" AUOptions 2                     # 2 = notify before download and before install
    reg_dword "$HKLMP\Windows\WindowsUpdate\AU" NoAutoRebootWithLoggedOnUsers 1
    reg_dword "$HKLMP\Windows\WindowsUpdate\AU" AlwaysAutoRebootAtScheduledTime 0
    # widest "active hours" Windows allows (18 h), matching the working day 09:00-03:00
    reg_dword "$HKLMP\Windows\WindowsUpdate" SetActiveHours 1
    reg_dword "$HKLMP\Windows\WindowsUpdate" ActiveHoursStart 9
    reg_dword "$HKLMP\Windows\WindowsUpdate" ActiveHoursEnd 3
    reg_dword "$HKLMP\Windows\WindowsUpdate" ExcludeWUDriversInQualityUpdate 0   # ordinary drivers via WU are fine
    # ...but never firmware: block installing any driver of the Firmware device class, which is how
    # Windows Update delivers UEFI/BIOS capsule updates. Lift it only for a deliberate BIOS update.
    # (gpedit: System > Device Installation > Device Installation Restrictions >
    #  "Prevent installation of devices using drivers that match these device setup classes")
    reg_dword "$HKLMP\Windows\DeviceInstall\Restrictions" DenyDeviceClasses 1
    reg_dword "$HKLMP\Windows\DeviceInstall\Restrictions" DenyDeviceClassesRetroactive 0
    reg_sz    "$HKLMP\Windows\DeviceInstall\Restrictions\DenyDeviceClasses" 1 '{f2e7dd72-6468-4e36-b6f1-6488f42c1b52}'
    reg_dword "$HKLMP\Windows\WindowsUpdate" DeferFeatureUpdates 1
    reg_dword "$HKLMP\Windows\WindowsUpdate" DeferFeatureUpdatesPeriodInDays 180
    reg_dword "$HKLMP\Windows\DeliveryOptimization" DODownloadMode 0           # no peer-to-peer uploading
fi

# ── telemetry, ads, Copilot, Recall, widgets, OneDrive personal ────────
if want privacy; then
    hdr "telemetry minimum, no ads, no Copilot/Recall/widgets, no personal OneDrive"
    reg_dword "$HKLMP\Windows\DataCollection" AllowTelemetry 1                  # Pro's minimum ("Required")
    reg_dword "$HKLMP\Windows\DataCollection" DoNotShowFeedbackNotifications 1
    reg_dword "$HKLMP\Windows\AdvertisingInfo" DisabledByGroupPolicy 1
    reg_dword "$HKLMP\Windows\CloudContent" DisableSoftLanding 1
    reg_dword "$HKLMP\Windows\CloudContent" DisableCloudOptimizedContent 1
    reg_dword "$HKLMP\Windows\CloudContent" DisableWindowsConsumerFeatures 1    # Ent
    reg_dword "$HKCUP\Windows\CloudContent" DisableTailoredExperiencesWithDiagnosticData 1
    reg_dword "$HKCUP\Windows\WindowsCopilot" TurnOffWindowsCopilot 1
    reg_dword "$HKLMP\Windows\WindowsCopilot" TurnOffWindowsCopilot 1
    reg_dword "$HKLMP\Windows\WindowsAI" DisableAIDataAnalysis 1                # Recall snapshots
    reg_dword "$HKLMP\Windows\WindowsAI" AllowRecallEnablement 0
    # Widgets: reg.exe gets "Access is denied" on this key (User Choice Protection Driver blocks
    # reg.exe/PowerShell here). Set it in gpedit.msc instead: Computer Configuration > Administrative
    # Templates > Windows Components > Widgets > Allow Widgets = Disabled (done on dalekanium 2026-11-02).
    reg_dword "$HKCUP\Windows\Explorer" DisableSearchBoxSuggestions 1           # no Bing results in Start search
    # OneDrive: block the PERSONAL account and folder "backup"; the UTSA work account keeps working
    reg_dword 'HKLM\SOFTWARE\Policies\Microsoft\OneDrive' DisablePersonalSync 1
    reg_dword 'HKLM\SOFTWARE\Policies\Microsoft\OneDrive' KFMBlockOptIn 1
    reg_dword 'HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' ScoobeSystemSettingEnabled 0  # "Let's finish setting up"
    for v in ContentDeliveryAllowed SilentInstalledAppsEnabled SoftLandingEnabled SystemPaneSuggestionsEnabled \
             SubscribedContent-338388Enabled SubscribedContent-338389Enabled SubscribedContent-310093Enabled \
             SubscribedContent-353694Enabled SubscribedContent-353696Enabled OemPreInstalledAppsEnabled PreInstalledAppsEnabled; do
        reg_dword "$CDM" "$v" 0
    done
    reg_dword 'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' Enabled 0
fi

# ── Edge: pretend it doesn't exist ─────────────────────────────────────
if want edge; then
    hdr "Edge: no first-run, no default-browser nagging, no background running, no promotions"
    E="$HKLMP\Edge"
    reg_dword "$E" HideFirstRunExperience 1
    reg_dword "$E" DefaultBrowserSettingEnabled 0          # stops "make Edge your default" prompts
    reg_dword "$E" DefaultBrowserSettingsCampaignEnabled 0
    reg_dword "$E" StartupBoostEnabled 0                   # no preloading at sign-in
    reg_dword "$E" BackgroundModeEnabled 0                 # no running after its window closes
    reg_dword "$E" ShowRecommendationsEnabled 0
    reg_dword "$E" PromotionalTabsEnabled 0
    reg_dword "$E" HubsSidebarEnabled 0
    reg_dword "$E" EdgeShoppingAssistantEnabled 0
    reg_dword "$E" PersonalizationReportingEnabled 0
    reg_dword "$E" ImportOnEachLaunch 0
    reg_dword "$E" AutoImportAtFirstRun 4                  # never import from Chrome
    reg_dword "$HKLMP\EdgeUpdate" CreateDesktopShortcutDefault 0
fi

# ── default apps: Chrome for web, enforced at every sign-in ────────────
if want defaults; then
    hdr "default apps from default-apps.xml (re-applied by Windows at each sign-in)"
    DEST='C:\ProgramData\dalekanium'
    run mkdir -p "/c/ProgramData/dalekanium"
    run cp "$HERE/default-apps.xml" "/c/ProgramData/dalekanium/default-apps.xml"
    reg_sz "$HKLMP\Windows\System" DefaultAssociationsConfiguration "$DEST\default-apps.xml"
fi

# ── lock screen and sign-in screen: plain, no web content ──────────────
if want lockscreen; then
    hdr "lock/sign-in screens: no Spotlight, no 'fun facts', no widgets, plain background"
    reg_dword "$CDM" RotatingLockScreenEnabled 0
    reg_dword "$CDM" RotatingLockScreenOverlayEnabled 0
    reg_dword "$CDM" SubscribedContent-338387Enabled 0                         # lock-screen "fun facts"
    reg_dword "$HKLMP\Dsh" DisableWidgetsOnLockScreen 1
    reg_dword "$HKLMP\Windows\System" DisableLogonBackgroundImage 1            # sign-in screen: solid colour
    reg_dword "$HKLMP\Windows\System" DisableAcrylicBackgroundOnLogon 1
    reg_dword "$HKCUP\Windows\CloudContent" DisableWindowsSpotlightFeatures 1   # Ent
    reg_dword "$HKLMP\Windows\Personalization" NoLockScreen 1                   # Ent: skip the lock screen entirely
fi

# ── shell: classic menus, Explorer as before, quiet taskbar ────────────
if want shell; then
    hdr "Explorer and taskbar"
    run reg.exe add 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' /ve /t REG_SZ /d "" /f   # classic right-click menu
    reg_dword 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' 0   # "This PC" on the desktop
    # (Win+V stays Windows' clipboard/emoji panel; Shift+Win+V is redirected to Ditto by kanata)
    reg_dword "$ADV" Hidden 1
    reg_dword "$ADV" ShowSuperHidden 1
    reg_dword "$ADV" HideFileExt 0
    reg_dword "$ADV" ShowStatusBar 1
    reg_dword "$ADV" LaunchTo 1                     # Explorer opens on This PC
    reg_dword "$ADV" Start_TrackDocs 0
    reg_dword "$ADV" EnableBalloonTips 0
    reg_dword "$ADV" TaskbarAl 0                    # taskbar icons left, Start button at the corner
    reg_dword "$ADV" ShowTaskViewButton 1
    reg_dword "$ADV" ShowCopilotButton 0
    reg_dword "$ADV" Start_IrisRecommendations 0    # no "recommended" tips in Start
    reg_dword "$ADV" Start_AccountNotifications 0
    reg_dword 'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 0   # no search box
fi

# ── keyboard ───────────────────────────────────────────────────────────
if want input; then
    hdr "keyboard layouts: US + US-International (Caps Lock behaviour comes from kanata, see kanata.kbd)"
    # No Scancode Map: a driver-level Caps->Ctrl remap would hide Caps Lock from kanata.
    # Windows 11 keeps keyboards inside the per-user language list; the old Preload registry
    # keys are not enough. 0409:00000409 = US, 0409:00020409 = United States-International.
    run powershell.exe -NoProfile -NonInteractive -Command \
        "\$l = Get-WinUserLanguageList; \$en = \$l | Where-Object LanguageTag -eq 'en-US'; \$en.InputMethodTips.Clear(); \$en.InputMethodTips.Add('0409:00000409'); \$en.InputMethodTips.Add('0409:00020409'); Set-WinUserLanguageList \$l -Force"
fi

# ── known folders and HOME ─────────────────────────────────────────────
if want folders; then
    hdr "known folders -> M:\\Eduardo\\...; HOME=M:\\Eduardo (AppData stays on C:)"
    USF='HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    while IFS='|' read -r name dir; do
        [[ -z $name ]] && continue
        reg_xsz "$USF" "$name" "M:\\Eduardo\\$dir"
    done <<'EOF'
Desktop|Desktop
Personal|Documents
{F42EE2D3-909F-4907-8871-4C22FC0BF756}|Documents
{374DE290-123F-4565-9164-39C4925E467B}|Downloads
{7D83EE9B-2244-4E70-B1F5-5393042AF1E4}|Downloads
My Pictures|Pictures
{0DDD015D-B06C-45D5-8C4C-F59713854639}|Pictures
My Music|Music
{A0C69A99-21C8-4671-8703-7934162FCF1D}|Music
My Video|Videos
{35286A68-3C57-41A1-BBB1-0EAE73D76C95}|Videos
Favorites|Favorites
{56784854-C6CB-462b-8169-88E350ACB882}|Contacts
{bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968}|Links
{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}|Saved Games
{7d1d3a04-debb-4115-95cf-2f29da2920da}|Searches
{31C0DD25-9439-4F12-BF41-7FF4EDA38722}|3D Objects
EOF
    reg_sz 'HKCU\Environment' HOME 'M:\Eduardo'
    echo "  (anything already saved in C:\\Users\\Eduardo\\Desktop, Documents, ... stays there: move it to M: by hand)"
fi

# ── power: sleep when idle, never hibernate, allow scheduled wake ──────
if want power; then
    hdr "power: sleep 30 min, display 10 min, hibernate off, wake timers on, USB selective suspend off"
    run powercfg.exe /hibernate off
    run powercfg.exe /change standby-timeout-ac 30
    run powercfg.exe /change monitor-timeout-ac 10
    run powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_SLEEP bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d 1
    run powercfg.exe /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    run powercfg.exe /setactive SCHEME_CURRENT
fi

# ── Windows Terminal: cmd and Git Bash start in M:\Eduardo; PowerShell hidden ──
if want terminal; then
    hdr "Windows Terminal profiles (fragment): cmd/Git Bash start in M:\\Eduardo, Git Bash (admin) added, PowerShell + Azure hidden"
    FRAG="${LOCALAPPDATA//\\//}/Microsoft/Windows Terminal/Fragments/dalekanium"
    run mkdir -p "$FRAG"
    run cp "$HERE/terminal-fragment.json" "$FRAG/profiles.json"
    echo "  (pick the default profile once: Terminal -> Settings -> Startup -> Default profile)"
fi

echo
if $APPLY; then
    echo "Done, $FAILS failure(s). Sign out and back in (restart if the computer was renamed)."
    for f in "${FAILED[@]}"; do echo "  failed: $f"; done
    echo "Log: $(cygpath -w "$LOG" 2>/dev/null || echo "$LOG")"
else
    echo "Dry run finished. Review the list above, then: bash configure.sh --apply"
fi
