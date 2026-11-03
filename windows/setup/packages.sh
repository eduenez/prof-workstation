#!/usr/bin/env bash
# windows/setup/packages.sh — Phase 6 of windows/dalekanium/PLAN.md: software.
#
# From an ELEVATED cmd:
#   M:\Eduardo\repos\prof-workstation\windows\setup\packages.cmd                 (dry run: checks every id)
#   M:\Eduardo\repos\prof-workstation\windows\setup\packages.cmd --apply
#   M:\Eduardo\repos\prof-workstation\windows\setup\packages.cmd --apply msys2   (only some sections)
# Sections, in order: remove apps msys2 kanata sync emacs wsl
#   remove  preinstalled Store apps in appx-remove.txt
#   apps    winget-machine.txt, always --scope machine (never falls back to a per-user install)
#   msys2   pacman update + msys2-packages.txt (needs MSYS2 from "apps")
#   kanata  kanata (tray build) + kanata.kbd + a sign-in task (test kanata.kbd by hand first)
#   sync    rename the old sync folders under M:\Eduardo\synchro, then winget-sync.txt
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
SECTIONS=${*:-"remove apps msys2 kanata sync emacs wsl"}
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
if want kanata; then
    hdr "kanata (tray build jtroo.kanata_gui); test first by hand"
    if ! $APPLY; then
        winget.exe show -e --id jtroo.kanata_gui --accept-source-agreements </dev/null >/dev/null 2>&1 \
            && echo "  ok       jtroo.kanata_gui" || echo "  UNKNOWN  jtroo.kanata_gui"
        echo "  would: install it machine-wide, copy kanata.kbd to C:\\ProgramData\\dalekanium,"
        echo "         create the sign-in task 'dalekanium\\kanata' (highest privileges, so it also works in admin windows)"
    else
        winget.exe list -e --id jtroo.kanata_gui </dev/null >/dev/null 2>&1 \
            || run winget.exe install -e --id jtroo.kanata_gui --scope machine "${WG[@]}"
        run cp "$HERE/kanata.kbd" /c/ProgramData/dalekanium/kanata.kbd
        KEXE=$(where.exe kanata_gui 2>/dev/null | head -1 | tr -d '\r')
        [[ -z $KEXE ]] && KEXE=$(ls /c/Program\ Files/WinGet/Links/kanata*.exe 2>/dev/null | head -1)
        [[ -z $KEXE ]] && KEXE=$(find /c/Program\ Files/WinGet/Packages -maxdepth 3 -iname 'kanata*.exe' 2>/dev/null | head -1)
        [[ $KEXE == /* ]] && KEXE=$(cygpath -w "$KEXE")
        if [[ -z $KEXE ]]; then
            echo "  !! kanata_gui.exe not found; open a new cmd and re-run this section"; FAILED+=("kanata: exe not found")
        else
            run schtasks.exe /create /tn 'dalekanium\kanata' /sc onlogon /rl highest /f \
                /tr "\"$KEXE\" -c C:\\ProgramData\\dalekanium\\kanata.kbd"
            echo "  starts at each sign-in; start it now with: schtasks /run /tn dalekanium\\kanata"
        fi
    fi
fi

# ── sync clients, after freeing M:\Eduardo\synchro ─────────────────────
if want sync; then
    hdr "old sync folders -> new places (nothing deleted), then sync clients (winget-sync.txt)"
    S=/m/Eduardo/synchro
    if [[ -d $S && ! -e /m/Eduardo/synchro-legacy ]]; then
        for od in "$S"/OneDrive*; do [[ -d $od ]] && run mv -n "$od" /m/Eduardo/; done
        [[ -d $S/private ]] && run mv -n "$S/private" /m/Eduardo/Tresorit-old
        run mv -n "$S" /m/Eduardo/synchro-legacy
        echo "  M:\\Eduardo\\synchro is now free for Syncthing; .emacs.d still points into synchro-legacy until the Emacs setup"
    else
        echo "  already done (or no old synchro folder)"
    fi
    winget_machine winget-sync.txt
    echo "  OneDrive (UTSA): sign in, Change location -> M:\\Eduardo -> 'Use this location'"
    echo "  Tresorit (manual install, not in winget): sync into a new, empty M:\\Eduardo\\Tresorit; compare with Tresorit-old afterwards"
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
    if ! grep -qw -- "$D" <<<"$ONLINE"; then
        echo "  UNKNOWN  $D is not offered. 'wsl --list --online' says:"
        sed 's/^/             /' <<<"$ONLINE"
        echo "  Re-run with e.g.:  set WSL_DISTRO=Ubuntu  (in cmd) before packages.cmd"
    else
        $APPLY || echo "  ok       $D is offered"
        run mkdir -p /m/WSL
        run wsl.exe --install -d "$D" --location "M:\\WSL\\$D" --no-launch
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
