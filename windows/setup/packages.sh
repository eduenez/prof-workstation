#!/usr/bin/env bash
# windows/setup/packages.sh — Phase 6 of windows/dalekanium/PLAN.md: software.
#
# From an ELEVATED cmd:
#   M:\Eduardo\repos\prof-workstation\windows\setup\packages.cmd                 (dry run: checks every id)
#   M:\Eduardo\repos\prof-workstation\windows\setup\packages.cmd --apply
#   M:\Eduardo\repos\prof-workstation\windows\setup\packages.cmd --apply msys2   (only some sections)
# Sections, in order: remove apps msys2 kanata sync syncthing emacs wsl
#   remove  preinstalled Store apps in appx-remove.txt
#   apps    winget-machine.txt, always --scope machine (never falls back to a per-user install)
#   msys2   pacman update + msys2-packages.txt (needs MSYS2 from "apps")
#   kanata  kanata (tray build) + kanata.kbd + a sign-in task with admin rights
#           (section kanata-user instead: same, without admin rights)
#   sync    winget-sync.txt (Dropbox, Google Drive); sync roots were moved by hand (see section)
#   syncthing  sign-in task for Syncthing (no console, no browser); pairing is manual (PLAN.md Phase 7)
#   emacs   native Emacs wired to the shared elisp repo: Developer Mode (symlinks without admin),
#           clone eduenez/elisp, retire the old ~/.emacs and ~/.emacs.d link, Start-menu shortcut
#   wsl     Ubuntu 26.04 LTS, stored on M:\WSL\Ubuntu-26.04
# Not here (manual, see PLAN.md): Bitdefender, Microsoft 365 (UTSA), NVIDIA driver, TeX Live,
# Ghostscript and Tresorit (not in winget),
# WhatsApp and All the Unicode (Store), StartAllBack (optional), UTSA VPN.
# Log: C:\ProgramData\dalekanium\logs\packages-<date-time>.log

set -u
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

APPLY=false
[[ ${1:-} == --apply ]] && { APPLY=true; shift; }
SECTIONS=${*:-"remove apps msys2 kanata sync syncthing emacs wsl"}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOGDIR=/c/ProgramData/dalekanium/logs
LOG="$LOGDIR/packages-$(date +%Y%m%d-%H%M%S).log"
FAILED=()

net.exe session >/dev/null 2>&1 || { echo "Run from an elevated (Run as administrator) cmd or Git Bash." >&2; exit 1; }
mkdir -p "$LOGDIR"
$APPLY && echo "Logging to $(cygpath -w "$LOG")" || echo "DRY RUN — nothing will change. Re-run with --apply."

run() {   # print; execute when --apply; output to the log; remember failures
    printf '  %s\n' "$*"
    $APPLY || return 0
    printf '\n$ %s\n' "$*" >>"$LOG"
    "$@" </dev/null >>"$LOG" 2>&1; local rc=$?
    if (( rc != 0 )); then echo "    !! failed (exit $rc)"; echo "!! FAILED" >>"$LOG"; FAILED+=("$*"); fi
    return $rc
}
want() { [[ " $SECTIONS " == *" $1 "* ]]; }
hdr()  { printf '\n== %s\n' "$*"; }
list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$HERE/$1"; }   # ids from a list file
ps()   { powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$1" </dev/null; }
WG=(--accept-package-agreements --accept-source-agreements --disable-interactivity)

# logon_task NAME EXE ARGS ELEVATED(yes|no): run EXE at Eduardo's sign-in, forever.
# Not schtasks.exe /create: that gives every task a 72-hour time limit, after which Windows
# kills it (kanata and Syncthing must run for weeks). Also: run on battery, one instance only.
logon_task() {   # optional 5th argument: working directory (default: the program's own folder)
    local lvl=Limited; [[ $4 == yes ]] && lvl=Highest
    local wd=${5:-}
    [[ -z $wd ]] && wd=${2%\\*}             # the program's folder (strip "\name.exe")
    echo "    run level: $lvl; working directory: $wd"
    run ps "\$a = New-ScheduledTaskAction -Execute '$2' -Argument '$3' -WorkingDirectory '$wd'; \$t = New-ScheduledTaskTrigger -AtLogOn -User \$env:USERNAME; \$s = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew; \$p = New-ScheduledTaskPrincipal -UserId \$env:USERNAME -LogonType Interactive -RunLevel $lvl; Register-ScheduledTask -TaskPath '\\dalekanium\\' -TaskName '$1' -Action \$a -Trigger \$t -Settings \$s -Principal \$p -Force | Out-Null"
}

winget_machine() {   # winget_machine LISTFILE
    local id
    while read -r id; do
        if ! $APPLY; then   # dry run: confirm the id exists
            if winget.exe show -e --id "$id" --accept-source-agreements </dev/null >/dev/null 2>&1; then
                printf '  ok       %s\n' "$id"
            else
                printf '  UNKNOWN  %s  (ids are case-sensitive with -e). winget search %s:\n' "$id" "${id##*.}"
                winget.exe search "${id##*.}" --accept-source-agreements </dev/null 2>/dev/null \
                    | tr -d '\r' | grep -v '^[-\\|/ ]*$' | tail -n +2 | head -6 | sed 's/^/             /'
            fi
            continue
        fi
        if winget.exe list -e --id "$id" --accept-source-agreements </dev/null >/dev/null 2>&1; then
            printf '  present  %s\n' "$id"; continue
        fi
        run winget.exe install -e --id "$id" --scope machine "${WG[@]}"
    done < <(list "$1")
}

# ── remove preinstalled Store apps ─────────────────────────────────────
if want remove; then
    hdr "remove preinstalled Store apps (appx-remove.txt)"
    while read -r name; do
        run ps "Get-AppxPackage -AllUsers -Name '$name' | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue; Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq '$name' | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null"
    done < <(list appx-remove.txt)
fi

# ── machine-wide applications ──────────────────────────────────────────
if want apps; then
    hdr "applications, machine-wide (winget-machine.txt)"
    winget_machine winget-machine.txt
fi

# ── MSYS2: native Emacs and Unix tools ─────────────────────────────────
if want msys2; then
    hdr "MSYS2 packages (msys2-packages.txt)"
    MB=(env MSYSTEM=UCRT64 CHERE_INVOKING=1 /c/msys64/usr/bin/bash.exe)
    if [[ ! -x /c/msys64/usr/bin/bash.exe ]]; then
        echo "  MSYS2 not installed yet (section apps installs it)"
    else
        # pacman updates its own core first and exits; the second pass updates the rest
        run "${MB[@]}" -lc "pacman -Syu --noconfirm"     # may report failure: it restarts itself
        run "${MB[@]}" -lc "pacman -Syu --noconfirm"
        run "${MB[@]}" -lc "pacman -S --needed --noconfirm $(list msys2-packages.txt | tr '\n' ' ')"
        echo "  Emacs: C:\\msys64\\ucrt64\\bin\\runemacs.exe (Start-menu shortcut comes later with the Emacs setup)"
    fi
fi

# ── kanata: Caps Lock = Esc/Ctrl, started at sign-in ───────────────────
# winget has the tray-icon build (jtroo.kanata_gui): same engine, no console window, and a
# tray menu to reload or quit. It is a "portable" package: winget puts it under
# C:\Program Files\WinGet and adds a kanata_gui command to PATH (new cmd window needed).
if want kanata || want kanata-user; then
    hdr "kanata (tray build jtroo.kanata_gui); test first by hand"
    if ! $APPLY; then
        winget.exe show -e --id jtroo.kanata_gui --accept-source-agreements </dev/null >/dev/null 2>&1 \
            && echo "  ok       jtroo.kanata_gui" || echo "  UNKNOWN  jtroo.kanata_gui"
        echo "  would: install it machine-wide; the task reads kanata.kbd from this repo folder,"
        echo "         create the sign-in task 'dalekanium\\kanata' (highest privileges, so it also works in admin windows)"
    else
        winget.exe list -e --id jtroo.kanata_gui </dev/null >/dev/null 2>&1 \
            || run winget.exe install -e --id jtroo.kanata_gui --scope machine "${WG[@]}"
        # the task reads kanata.kbd straight from the repo: no stale copy can linger in ProgramData
        KCFG=$(cygpath -w "$HERE/kanata.kbd")
        # the real program file, not winget's Links shortcut (the task crashed via the shortcut)
        # the package holds several builds; use the plain tray build (the one tested by hand),
        # not e.g. "..._cmd_allowed_..."
        KEXE=$(find /c/Program\ Files/WinGet/Packages -maxdepth 3 -iname 'kanata_windows_gui_winIOv2_x64.exe' 2>/dev/null | head -1)
        [[ -z $KEXE ]] && KEXE=$(ls /c/Program\ Files/WinGet/Links/kanata*.exe 2>/dev/null | head -1)
        [[ $KEXE == /* ]] && KEXE=$(cygpath -w "$KEXE")
        if [[ -z $KEXE ]]; then
            echo "  !! kanata_gui.exe not found; open a new cmd and re-run this section"; FAILED+=("kanata: exe not found")
        else
            # KANATA_ELEVATED=no (set in cmd before packages.cmd) runs it without admin rights:
            # then remapping does not reach windows that run as administrator
            ELEV=${KANATA_ELEVATED:-yes}; want kanata-user && ELEV=no   # section "kanata-user" = no admin rights
            logon_task kanata "$KEXE" "-c $KCFG" "$ELEV"    # path has no spaces
            echo "  starts at each sign-in; start it now with: schtasks /run /tn dalekanium\\kanata"
        fi
    fi
fi

# ── sync clients ───────────────────────────────────────────────────────
# Folder layout (decided 2026-11-03): work and third-party sync roots live OUTSIDE the home
# directory, at the root of M:  —  M:\OneDrive - University of Texas at San Antonio (UTSA work
# account), M:\private (old Tresorit copy). M:\Eduardo\synchro is now empty and reserved for
# Syncthing. Only the clients are installed here; signing in is manual (see the notes printed).
if want sync; then
    hdr "sync clients (winget-sync.txt); folders already moved by hand"
    winget_machine winget-sync.txt
    echo "  Dropbox: rename the old local M:\\Eduardo\\Dropbox first (it still holds pre-prune folders);"
    echo "           sign in, Advanced settings -> location M:\\Eduardo, keep files available offline"
    echo "  Google Drive: Settings -> Google Drive -> Mirror files -> M:\\Eduardo\\GoogleDrive"
    echo "  OneDrive (UTSA): Change location -> M:\\ (the drive root) -> 'Use this location'"
    echo "  Tresorit (manual install): sync into a new, empty M:\\Tresorit; compare with M:\\private afterwards"
fi

# ── Syncthing: started at sign-in, no console window, no browser ───────
if want syncthing; then
    hdr "Syncthing sign-in task (pairing is manual: PLAN.md Phase 7)"
    SEXE=$(where.exe syncthing 2>/dev/null </dev/null | head -1 | tr -d '\r')
    [[ -z $SEXE ]] && SEXE=$(find /c/Program\ Files/WinGet/Packages -maxdepth 3 -iname 'syncthing.exe' 2>/dev/null | head -1)
    [[ $SEXE == /* ]] && SEXE=$(cygpath -w "$SEXE")
    if [[ -z $SEXE ]]; then
        echo "  !! syncthing.exe not found (section apps installs it)"; $APPLY && FAILED+=("syncthing: exe not found")
    else
        echo "  found $SEXE"
        logon_task syncthing "$SEXE" '--no-console --no-browser' no
        echo "  start now: schtasks /run /tn dalekanium\\syncthing ; GUI: http://127.0.0.1:8384"
    fi
fi

# ── Emacs: native MSYS2 build + the shared elisp repo ──────────────────
if want emacs; then
    hdr "Emacs: ~/.emacs.d -> M:\\Eduardo\\repos\\elisp (HOME is M:\\Eduardo)"
    # Developer Mode lets programs create symlinks without admin rights (Elpaca and git need that)
    run reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f
    if [[ -d /m/Eduardo/repos/elisp/.git ]]; then echo "  elisp repo present"
    else run git clone git@github.com:eduenez/elisp.git /m/Eduardo/repos/elisp; fi
    # Emacs reads ~/.emacs BEFORE ~/.emacs.d/init.el, so the old SuSE-era file must step aside
    [[ -e /m/Eduardo/.emacs ]] && run mv -n /m/Eduardo/.emacs /m/Eduardo/.emacs.pre-dalekanium
    # the old ~/.emacs.d is a link into the legacy synchro tree: rename it (nothing deleted)
    if [[ -e /m/Eduardo/.emacs.d || -L /m/Eduardo/.emacs.d ]]; then
        if [[ $(cygpath -w "$(readlink -f /m/Eduardo/.emacs.d 2>/dev/null)" 2>/dev/null) == 'M:\Eduardo\repos\elisp' ]]; then
            echo "  ~/.emacs.d already points to repos\\elisp"
        else run mv -n /m/Eduardo/.emacs.d /m/Eduardo/.emacs.d.legacy; fi
    fi
    [[ -e /m/Eduardo/.emacs.d ]] || run cmd.exe /d /c mklink /J 'M:\Eduardo\.emacs.d' 'M:\Eduardo\repos\elisp'
    # Start-menu shortcut (all users) for runemacs, started in M:\Eduardo
    run ps "\$s = (New-Object -ComObject WScript.Shell).CreateShortcut('C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Emacs.lnk'); \$s.TargetPath = 'C:\msys64\ucrt64\bin\runemacs.exe'; \$s.WorkingDirectory = 'M:\Eduardo'; \$s.Save()"
    echo "  first start: Elpaca builds every package (several minutes). The elisp config must put"
    echo "  C:\\msys64\\ucrt64\\bin and C:\\msys64\\usr\\bin on exec-path for git/rg/aspell (next step)."
fi

# ── WSL: Ubuntu 26.04 LTS on M: ────────────────────────────────────────
if want wsl; then
    D=${WSL_DISTRO:-Ubuntu-26.04}     # override: set WSL_DISTRO=<name from wsl --list --online>
    hdr "WSL: $D stored on M:\\WSL\\$D"
    ONLINE=$(wsl.exe --list --online 2>&1 </dev/null | tr -d '\0\r')
    if wsl.exe --list --quiet 2>/dev/null </dev/null | tr -d '\0\r' | grep -qx -- "$D"; then
        echo "  $D is already installed (wsl --list --verbose)"
    elif ! grep -qw -- "$D" <<<"$ONLINE"; then
        echo "  UNKNOWN  $D is not offered. 'wsl --list --online' says:"
        sed 's/^/             /' <<<"$ONLINE"
        echo "  Re-run with e.g.:  set WSL_DISTRO=Ubuntu  (in cmd) before packages.cmd"
        $APPLY && FAILED+=("wsl: $D not offered")
    elif ! $APPLY; then
        echo "  ok       $D is offered; would install it to M:\\WSL\\$D"
    else
        run mkdir -p /m/WSL
        # shown live as well as logged: this downloads several hundred MB
        echo "  wsl --install -d $D --location M:\\WSL\\$D --no-launch"
        printf '\n$ wsl --install -d %s\n' "$D" >>"$LOG"
        wsl.exe --install -d "$D" --location "M:\\WSL\\$D" --no-launch </dev/null 2>&1 | tr -d '\0\r' | tee -a "$LOG"
        rc=${PIPESTATUS[0]}
        (( rc == 0 )) || { echo "    !! failed (exit $rc)"; FAILED+=("wsl --install -d $D"); }
        wsl.exe --list --verbose </dev/null 2>&1 | tr -d '\0\r' | sed 's/^/    /'
    fi
    echo "  then open '$D' once to create the Linux user (eduenez), and run prof-workstation's Linux features inside it"
fi

echo
if $APPLY; then
    echo "Done, ${#FAILED[@]} failure(s)."; for f in "${FAILED[@]}"; do echo "  failed: $f"; done
    echo "Log: $(cygpath -w "$LOG")"
else
    echo "Dry run finished. Fix any UNKNOWN ids, then re-run with --apply."
fi
