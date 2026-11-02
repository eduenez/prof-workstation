#!/usr/bin/env bash
# windows/inventory.sh — read-only snapshot of a Windows machine's configuration,
# taken before a clean reinstall so the new install can be rebuilt from a spec.
#
# Runs from Cygwin bash or WSL (it calls the Windows tools reg.exe,
# winget.exe, schtasks.exe, ... directly; a few queries go through generated
# .ps1 files, so you never type PowerShell). It changes nothing on the system.
#
# Usage:   bash inventory.sh [OUTDIR]        (SKIP_DRIVERS=1 to skip the ~2 GB driver export)
# Default: M:\Eduardo\win-inventory\<HOST>-<YYYYmmdd-HHMM>
#
# Run it from an ELEVATED terminal (right-click mintty / Windows Terminal ->
# "Run as administrator") to also capture the admin-only parts: drivers export,
# optional features, local Group Policy, BitLocker, TPM, boot config. Without
# elevation those parts are skipped and listed in _log.txt.
#
# The output holds machine details (hostnames, Wi-Fi profile names, paths) and
# is meant to stay OUT of git. A reviewed, curated spec derived from it is what
# goes into the repo.

set -u

# ── Environment ────────────────────────────────────────────────────────
if command -v cygpath >/dev/null 2>&1; then
    ENV=cygwin
    winpath()  { cygpath -w "$1"; }
    unixpath() { cygpath -u "$1"; }
elif command -v wslpath >/dev/null 2>&1; then
    ENV=wsl
    winpath()  { wslpath -w "$1"; }
    unixpath() { wslpath -u "$1"; }
else
    echo "Run this from Cygwin bash or WSL." >&2; exit 1
fi

HOST=$(hostname)
STAMP=$(date +%Y%m%d-%H%M)
OUT=${1:-$(unixpath 'M:\Eduardo')/win-inventory/$HOST-$STAMP}
mkdir -p "$OUT" || exit 1
OUT=$(cd "$OUT" && pwd)
TMPD="$OUT/_tmp"; mkdir -p "$TMPD"
cd "$OUT" || exit 1          # keep cmd.exe off a UNC working directory under WSL

if net.exe session >/dev/null 2>&1; then ADMIN=true; else ADMIN=false; fi

log() { printf '%s\n' "$*" | tee -a "$OUT/_log.txt" >&2; }

# run NAME cmd...   -> stdout to $OUT/NAME (CR stripped), failures logged
run() {
    local name=$1; shift
    mkdir -p "$(dirname "$OUT/$name")"
    "$@" 2>"$OUT/$name.err" | tr -d '\r' >"$OUT/$name"
    local rc=${PIPESTATUS[0]}
    (( rc == 0 )) || log "FAIL  $name  (exit $rc: $*)"
}

# cim NAME CLASS PROPS   (WMI/CIM query through PowerShell; wmic is deprecated and absent on Windows 11)
cim() {
    ps "$1" <<EOF
Get-CimInstance $2 | Select-Object $3 | Format-List | Out-String -Width 400
EOF
}

# rx NAME KEY   -> registry/NAME.reg (UTF-16, re-importable) + NAME.txt (UTF-8, greppable)
rx() {
    local name=$1 key=$2 f="$OUT/registry/$1.reg"
    mkdir -p "$OUT/registry"
    if reg.exe export "$key" "$(winpath "$f")" /y >/dev/null 2>&1; then
        iconv -f UTF-16 -t UTF-8 "$f" | tr -d '\r' >"$OUT/registry/$name.txt"
    else
        log "absent  registry $key"
    fi
}

# ps NAME   (PowerShell source on stdin; run via a temp .ps1, UTF-8 output)
ps() {
    local name=$1 f="$TMPD/$(printf '%s' "$1" | tr '/.' '__').ps1"
    { echo '[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false'
      echo '$ErrorActionPreference = "Stop"'
      cat; } >"$f"
    run "$name" powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(winpath "$f")"
}

# lsd NAME WINPATH   (directory listing, incl. hidden/dotfiles)
lsd() {
    local name=$1 p; p=$(unixpath "$2")
    mkdir -p "$(dirname "$OUT/$name")"
    if [[ -d $p ]]; then ls -la --time-style=long-iso "$p" >"$OUT/$name" 2>&1
    else log "absent  folder $2"; fi
}

# cpw DEST WINPATH   (copy a file or directory if it exists)
cpw() {
    local dest=$1 p; p=$(unixpath "$2")
    mkdir -p "$OUT/$(dirname "$dest")"
    if [[ -e $p ]]; then cp -r "$p" "$OUT/$dest" 2>>"$OUT/_log.txt" || log "FAIL  copy $2"
    else log "absent  file $2"; fi
}

SYS32=$(unixpath 'C:\Windows\System32')   # explicit paths where Cygwin has a same-named tool
winenv() { cmd.exe /d /c "echo %$1%" 2>/dev/null | tr -d '\r'; }
need_admin() { $ADMIN || { log "skip  $1  (not elevated)"; return 1; }; }

USERPROFILE_W=$(winenv USERPROFILE)
APPDATA_W=$(winenv APPDATA)
LOCALAPPDATA_W=$(winenv LOCALAPPDATA)

{
    echo "host:      $HOST"
    echo "taken:     $(date -Iseconds)"
    echo "shell env: $ENV"
    echo "elevated:  $ADMIN"
    echo "USERPROFILE=$USERPROFILE_W"
    echo "APPDATA=$APPDATA_W"
    echo "LOCALAPPDATA=$LOCALAPPDATA_W"
} >"$OUT/_meta.txt"
log "Writing inventory to $(winpath "$OUT")  (elevated: $ADMIN)"

# ── 1. System, hardware, Windows 11 eligibility ────────────────────────
log "1/9 system"
run system/systeminfo.txt          systeminfo.exe
run system/winver.txt              reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
run system/activation.txt          cscript.exe //nologo 'C:\Windows\System32\slmgr.vbs' /dli
cim system/os.txt         Win32_OperatingSystem 'Caption,Version,BuildNumber,OSArchitecture,InstallDate'
cim system/cpu.txt        Win32_Processor       'Name,NumberOfCores,NumberOfLogicalProcessors'
cim system/computer.txt   Win32_ComputerSystem  'Manufacturer,Model,TotalPhysicalMemory'
cim system/bios.txt       Win32_BIOS            'Manufacturer,SMBIOSBIOSVersion,ReleaseDate'
cim system/baseboard.txt  Win32_BaseBoard       'Manufacturer,Product,Version'
ps  system/firmware.txt <<'EOF'
$ErrorActionPreference = 'Continue'
"firmware_type: $env:firmware_type"
try { "SecureBootUEFI: " + (Confirm-SecureBootUEFI) } catch { "SecureBootUEFI: not available (legacy BIOS boot, or no admin)" }
EOF
ps  system/disks.txt <<'EOF'
Get-Disk | Format-Table Number,FriendlyName,BusType,PartitionStyle,@{n='GB';e={[math]::Round($_.Size/1GB)}} -AutoSize | Out-String -Width 250
Get-Partition | Format-Table DiskNumber,PartitionNumber,DriveLetter,Type,@{n='GB';e={[math]::Round($_.Size/1GB)}} -AutoSize | Out-String -Width 250
Get-Volume | Format-Table DriveLetter,FileSystemLabel,FileSystem,DriveType,@{n='GB';e={[math]::Round($_.Size/1GB)}},@{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB)}} -AutoSize | Out-String -Width 250
EOF
rx  mounted-devices                'HKLM\SYSTEM\MountedDevices'
if need_admin "TPM / BitLocker / boot config"; then
    ps  system/tpm.txt <<'EOF'
Get-Tpm | Format-List
EOF
    run system/bitlocker.txt       manage-bde.exe -status
    run system/bcdedit.txt         bcdedit.exe /enum
fi

# ── 2. Installed software ──────────────────────────────────────────────
log "2/9 software"
ps  software/programs.csv <<'EOF'
$paths = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
         'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
         'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
Get-ItemProperty $paths -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -and -not $_.SystemComponent -and -not $_.ParentKeyName } |
  Select-Object DisplayName,DisplayVersion,Publisher,InstallDate,InstallLocation,
    @{n='Scope';e={ if ($_.PSPath -like '*HKEY_CURRENT_USER*') {'user'}
                    elseif ($_.PSPath -like '*WOW6432Node*') {'machine32'} else {'machine'} }} |
  Sort-Object DisplayName | ConvertTo-Csv -NoTypeInformation
EOF
ps  software/store-apps.csv <<'EOF'
Get-AppxPackage | Select-Object Name,Version,Publisher,IsFramework,NonRemovable,SignatureKind |
  Sort-Object Name | ConvertTo-Csv -NoTypeInformation
EOF
run software/winget-list.txt       winget.exe list --accept-source-agreements
run software/winget-export.log     winget.exe export -o "$(winpath "$OUT/software/winget-export.json")" \
                                       --include-versions --accept-source-agreements
lsd software/ProgramFiles.txt      'C:\Program Files'
lsd software/ProgramFiles-x86.txt  'C:\Program Files (x86)'
lsd software/ProgramData.txt       'C:\ProgramData'
lsd software/StartMenu-all.txt     'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'
lsd software/StartMenu-user.txt    "$APPDATA_W\\Microsoft\\Windows\\Start Menu\\Programs"
lsd software/TaskbarPins.txt       "$APPDATA_W\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar"
lsd software/AppData-Roaming.txt   "$APPDATA_W"
lsd software/AppData-Local.txt     "$LOCALAPPDATA_W"
if need_admin "provisioned apps / optional features / capabilities"; then
    ps software/provisioned-apps.csv <<'EOF'
Get-AppxProvisionedPackage -Online | Select-Object DisplayName,Version | Sort-Object DisplayName | ConvertTo-Csv -NoTypeInformation
EOF
    ps software/optional-features.txt <<'EOF'
Get-WindowsOptionalFeature -Online | Where-Object State -eq Enabled | Sort-Object FeatureName | ForEach-Object FeatureName
EOF
    ps software/capabilities.txt <<'EOF'
Get-WindowsCapability -Online | Where-Object State -eq Installed | Sort-Object Name | ForEach-Object Name
EOF
fi

# ── 3. User folders, environment, shell integration ────────────────────
log "3/9 folders & environment"
rx  user-shell-folders             'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
rx  shell-folders                  'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'
rx  env-user                       'HKCU\Environment'
rx  env-system                     'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
rx  profile-list                   'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
rx  cmd-processor                  'HKCU\Software\Microsoft\Command Processor'
rx  gnu-emacs                      'HKCU\Software\GNU'
lsd folders/USERPROFILE.txt        "$USERPROFILE_W"
lsd folders/M-Eduardo.txt          'M:\Eduardo'
lsd folders/C-root.txt             'C:\'
lsd folders/M-root.txt             'M:\'
lsd folders/Startup-user.txt       "$APPDATA_W\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
lsd folders/Startup-all.txt        'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp'
for d in "$USERPROFILE_W" 'M:\Eduardo'; do
    tag=$(printf '%s' "$d" | tr -c 'A-Za-z0-9' '_')
    for f in .bashrc .bash_profile .profile .zshrc .zprofile .inputrc .minttyrc .gitconfig \
             .emacs .tmux.conf .wslconfig .latexmkrc .Xresources; do
        [[ -f $(unixpath "$d")/$f ]] && cpw "dotfiles/$tag/$f" "$d\\$f"
    done
done
cpw terminal/WindowsTerminal-settings.json \
    "$LOCALAPPDATA_W\\Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\LocalState\\settings.json"

# ── 4. Desktop / Explorer / input / privacy settings ───────────────────
log "4/9 UI, keyboard, privacy"
rx  control-panel                  'HKCU\Control Panel'
rx  console                        'HKCU\Console'
rx  keyboard-layout-user           'HKCU\Keyboard Layout'
rx  keyboard-scancode-map          'HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
rx  explorer-advanced              'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
rx  explorer-hidedesktopicons      'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons'
rx  themes                         'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes'
rx  dwm                            'HKCU\Software\Microsoft\Windows\DWM'
rx  search                         'HKCU\Software\Microsoft\Windows\CurrentVersion\Search'
rx  content-delivery               'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
rx  advertising-info               'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
rx  privacy                        'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy'
rx  notifications                  'HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
rx  fonts-machine                  'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
rx  fonts-user                     'HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
lsd fonts/user-fonts.txt           "$LOCALAPPDATA_W\\Microsoft\\Windows\\Fonts"
lsd fonts/system-fonts.txt         'C:\Windows\Fonts'
rx  filesystem                     'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem'
rx  timezone                       'HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'

# ── 5. File associations, policies, update behaviour ───────────────────
log "5/9 associations & policies"
run assoc/assoc.txt                cmd.exe /d /c assoc
run assoc/ftype.txt                cmd.exe /d /c ftype
rx  user-fileexts                  'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts'
rx  user-classes                   'HKCU\Software\Classes'
rx  policies-user                  'HKCU\Software\Policies'
rx  policies-user-cv               'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies'
rx  policies-machine               'HKLM\SOFTWARE\Policies'
rx  policies-machine-cv            'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies'
rx  windowsupdate-ux               'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
rx  run-user                       'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'
rx  run-machine                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
rx  run-machine32                  'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
rx  openssh                        'HKLM\SOFTWARE\OpenSSH'
run policy/gpresult-user.txt       gpresult.exe /r /scope:user
if need_admin "local Group Policy / gpresult report"; then
    cpw policy/GroupPolicy         'C:\Windows\System32\GroupPolicy'
    run policy/gpresult.log        gpresult.exe /h "$(winpath "$OUT/policy/gpresult.html")" /f
fi

# ── 6. Services, scheduled tasks, startup, drivers ─────────────────────
log "6/9 services, tasks, drivers"
ps  services/services.csv <<'EOF'
Get-CimInstance Win32_Service | Select-Object Name,DisplayName,StartMode,State,PathName | Sort-Object Name | ConvertTo-Csv -NoTypeInformation
EOF
cim services/startup.txt  Win32_StartupCommand  'Caption,Command,Location' 
run services/scheduled-tasks.csv   schtasks.exe /query /fo csv /v
run services/drivers.csv           driverquery.exe /v /fo csv
if need_admin "driver export (dism)"; then
    if [[ ${SKIP_DRIVERS:-} == 1 ]]; then log "skip  driver export (SKIP_DRIVERS=1)"; else
    mkdir -p "$OUT/drivers"
    run drivers/_export.log        dism.exe /online /export-driver /destination:"$(winpath "$OUT/drivers")"
    fi
fi

# ── 7. Power, network, sharing, printing ───────────────────────────────
log "7/9 power & network"
run power/schemes.txt              powercfg.exe /list
run power/active-scheme.txt        powercfg.exe /query
run power/sleep-states.txt         powercfg.exe /availablesleepstates
run power/wake-armed.txt           powercfg.exe /devicequery wake_armed
$ADMIN && run power/waketimers.txt powercfg.exe /waketimers
run network/ipconfig.txt           ipconfig.exe /all
netsh.exe wlan show profiles 2>&1 | tr -d '\r' >"$OUT/network/wlan-profiles.txt" || log "note  no Wi-Fi on this machine (wlan service not running)"
run network/net-use.txt            net.exe use
run network/net-share.txt          net.exe share
run network/firewall-rules.txt     netsh.exe advfirewall firewall show rule name=all
cpw network/hosts                  'C:\Windows\System32\drivers\etc\hosts'
cim network/printers.txt  Win32_Printer  'Name,DriverName,PortName,Default' 
run accounts/whoami.txt            "$SYS32/whoami.exe" /all
run accounts/users.txt             net.exe user
run accounts/administrators.txt    net.exe localgroup Administrators

# ── 8. WSL ─────────────────────────────────────────────────────────────
log "8/9 WSL"
cpw wsl/.wslconfig                 "$USERPROFILE_W\\.wslconfig"
rx  wsl-lxss                       'HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss'
if command -v wsl.exe >/dev/null 2>&1; then
    mkdir -p "$OUT/wsl"
    wsl.exe --list --verbose 2>&1 | tr -d '\0\r' >"$OUT/wsl/distros.txt"
    wsl.exe --version        2>&1 | tr -d '\0\r' >"$OUT/wsl/version.txt"
    # every installed distro, not just the default one
    # names from the --verbose listing above (skip header, strip default-marker '*' and any BOM)
    mapfile -t DISTROS < <(sed -e '1d' -e 's/^\xEF\xBB\xBF//' -e 's/^[* \t]*//' -e 's/[ \t].*//' -e '/^$/d' "$OUT/wsl/distros.txt")
    log "    distros: ${DISTROS[*]:-none}"
    for d in "${DISTROS[@]}"; do
        w="wsl/$d"
        run "$w/os-release.txt"   wsl.exe -d "$d" -e sh -c 'cat /etc/os-release; echo; echo == wsl.conf; cat /etc/wsl.conf 2>/dev/null; echo; getent passwd $(id -un)'
        run "$w/packages.txt"     wsl.exe -d "$d" -e sh -c 'if command -v rpm >/dev/null; then rpm -qa | sort; elif command -v dpkg-query >/dev/null; then dpkg-query -W; fi'
        run "$w/home-listing.txt" wsl.exe -d "$d" -e sh -c 'ls -la ~; echo; echo == ~/.config; ls -la ~/.config 2>/dev/null'
        wsl.exe -d "$d" -e sh -c 'cd ~ && tar cf - $(ls -d .zshrc .zprofile .zshenv .bashrc .profile .gitconfig .tmux.conf .emacs .inputrc .ssh/config 2>/dev/null)' \
            >"$OUT/$w/dotfiles.tar" 2>/dev/null || log "note  $w dotfiles tar failed"
    done
else
    log "absent  WSL (wsl.exe not found)"
fi

# ── 9. Cygwin ──────────────────────────────────────────────────────────
log "9/9 Cygwin"
CYGROOT_W=
if [[ $ENV == cygwin ]]; then CYGROOT_W=$(cygpath -w /)
else for r in 'C:\cygwin64' 'C:\cygwin'; do [[ -d $(unixpath "$r") ]] && { CYGROOT_W=$r; break; }; done; fi
if [[ -n $CYGROOT_W ]]; then
    echo "$CYGROOT_W" >"$OUT/_cygwin-root.txt"
    for f in etc/fstab etc/nsswitch.conf etc/passwd etc/group etc/bash.bashrc etc/setup/installed.db etc/setup/setup.rc; do
        cpw "cygwin/$f" "$CYGROOT_W\\${f//\//\\}"
    done
    lsd cygwin/home.txt "$CYGROOT_W\\home"
else
    log "skip  Cygwin (no install found)"
fi

# ── Wrap up ────────────────────────────────────────────────────────────
find "$OUT" -name '*.err' -size 0 -delete 2>/dev/null
rm -rf "$TMPD"
{
    echo
    echo "Done: $(date -Iseconds)"
    echo "Files: $(find "$OUT" -type f | wc -l)   Size: $(du -sh "$OUT" | cut -f1)"
} | tee -a "$OUT/_log.txt" >&2
log "Inventory at: $(winpath "$OUT")"
