#!/usr/bin/env bash
# windows/setup/restic/restic.sh — Restic backups of dalekanium onto the WD Elements (W:).
# Phase 7 of windows/dalekanium/PLAN.md; design in filetree-reorg/design/restic_backup.md.
#
#   bash restic.sh setup [--apply]     ELEVATED. Dry run unless --apply: checks restic, creates the
#                                      password file (asks twice), initialises the repository, and
#                                      registers the nightly task. Safe to re-run; skips what exists.
#   bash restic.sh backup [--dry-run]  one backup now (elevated = with VSS, so open files are copied).
#                                      --dry-run lists what would be read and how much, changes nothing.
#   bash restic.sh nightly             what the scheduled task runs: keep awake, wait for Syncthing,
#                                      backup, forget; on Sundays also prune + check a 5% data sample.
#   bash restic.sh status              snapshots, repository size, last nightly result.
#   bash restic.sh restore-test [N]    restores N (default 20) random files from the latest snapshot
#                                      and compares them byte-for-byte (SHA-256) with the originals.
#   bash restic.sh restic ARGS...      any restic command against this repository (e.g. snapshots, mount).
#
# Offline copy on a portable SSD (usually unplugged), expected at drive V: (RESTIC_OFFLINE_DRIVE=<letter> to change;
# give the SSD that letter once in Disk Management and Windows keeps it).  If it is not there, the other drive letters
# are searched for its folder, except the fixed ones (C: F: G: M: W: X:).  exFAT or NTFS both work.
#   bash restic.sh offline-init [V:] [--apply] ELEVATED. Create V:\restic-dalekanium-offline with its own password
#                                              (C:\ProgramData\dalekanium\restic\password-offline + Bitwarden), with
#                                              the same chunker parameters as W:, so copies deduplicate.
#   bash restic.sh offline                     copy every snapshot of W: that the SSD lacks (`restic copy`: reads the
#                                              repository on W:, not the sources), then forget/prune with the same
#                                              policy, then check 5% of the SSD's data.  Eject the SSD afterwards.
#   bash restic.sh offline-restore-test [N]    restore test against the SSD.
#
# Repository  W:\restic-dalekanium   (never created anywhere else: if W: is missing, nothing runs)
# Password    C:\ProgramData\dalekanium\restic\password  (readable by Eduardo, SYSTEM, Administrators
#             only). The SAME password must be in Bitwarden: without it the backups are unreadable.
# Logs        C:\ProgramData\dalekanium\logs\restic-<date>.log, restic-last.txt (one line per run);
#             failures also go to the Windows Application event log (source dalekanium-restic).
set -u
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

export RESTIC_REPOSITORY='W:\restic-dalekanium'
export RESTIC_PASSWORD_FILE='C:\ProgramData\dalekanium\restic\password'
REPO_POSIX=/w/restic-dalekanium
PWDIR_POSIX=/c/ProgramData/dalekanium/restic
LOGDIR=/c/ProgramData/dalekanium/logs
TASK=restic-nightly; TASK_TIME=04:30
# What is backed up (Windows paths). M:\Eduardo includes synchro, secreto, GoogleDrive, Dropbox,
# private and repos; the work OneDrive lives outside the home directory.
SOURCES=(
  'M:\Eduardo'
  'M:\OneDrive - University of Texas at San Antonio'
  'C:\Users\Eduardo\AppData\Roaming'
  'C:\Users\Eduardo\.ssh'
  'C:\ProgramData\dalekanium'
)
KEEP=(--keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 3)
OFF_DIR=restic-dalekanium-offline
OFF_DRIVE=${RESTIC_OFFLINE_DRIVE:-V}; OFF_DRIVE=${OFF_DRIVE:0:1}; OFF_DRIVE=${OFF_DRIVE,,}
OFF_SKIP="c f g m w x"   # system, DVD, FreeAgent, data SSD, Elements, Google Drive: never the portable SSD
OFF_PW='C:\ProgramData\dalekanium\restic\password-offline'

is_admin() { net.exe session >/dev/null 2>&1; }
ts()  { date '+%F %T'; }
die() { echo "ERROR: $*" >&2; exit 1; }
find_restic() {
    RESTIC=$(command -v restic 2>/dev/null)
    [[ -z $RESTIC ]] && RESTIC=$(find "/c/Program Files/WinGet/Packages" -maxdepth 2 -iname 'restic*.exe' 2>/dev/null | head -1)
    [[ -n $RESTIC ]]
}
need_repo() {
    [[ -d /w ]] || die "W: (WD Elements) is not connected"
    [[ -f $REPO_POSIX/config ]] || die "no repository at $RESTIC_REPOSITORY (run: restic.sh setup --apply)"
    [[ -f $PWDIR_POSIX/password ]] || die "no password file $RESTIC_PASSWORD_FILE"
    find_restic || die "restic not found (winget install -e --id restic.restic --scope machine)"
}
r() { "$RESTIC" "$@"; }

find_offline() {   # -> OFF_POSIX (/x/restic-dalekanium-offline) and OFF_REPO (X:\restic-dalekanium-offline)
    local l d
    for l in "$OFF_DRIVE" {d..z}; do
        d=/$l
        [[ " $OFF_SKIP " == *" $l "* || ! -d $d ]] && continue
        if [[ -f $d/$OFF_DIR/config ]]; then
            OFF_POSIX=$d/$OFF_DIR; OFF_REPO="${d:1:1}"; OFF_REPO="${OFF_REPO^^}:\\$OFF_DIR"; return 0
        fi
    done
    return 1
}
ro() { "$RESTIC" -r "$OFF_REPO" --password-file "$OFF_PW" "$@"; }   # restic against the offline SSD
make_password() {   # make_password WINDOWS-PATH: ask twice, write it (the folder's restricted ACL is inherited)
    local P1 P2 f; f=$(cygpath -u "$1")
    read -rsp "New password (store it in Bitwarden too): " P1; echo
    read -rsp "Again: " P2; echo
    [[ -n $P1 && $P1 == "$P2" ]] || die "passwords empty or different"
    mkdir -p "$(dirname "$f")"; printf '%s' "$P1" >"$f"; unset P1 P2
}

do_backup() {   # do_backup [restic backup options...]
    local vss=(); is_admin && vss=(--use-fs-snapshot) || echo "(not elevated: no VSS, files open by other programs may be skipped)"
    r unlock >/dev/null 2>&1   # removes only stale locks
    r backup "${vss[@]}" --host DALEKANIUM --tag nightly --exclude-caches \
        --iexclude-file "$(cygpath -w "$HERE/excludes.txt")" "$@" "${SOURCES[@]}"
}

cmd=${1:-}; shift || true
case $cmd in
setup)
    APPLY=false; [[ ${1:-} == --apply ]] && APPLY=true
    is_admin || die "run setup from an elevated Git Bash or cmd"
    $APPLY || echo "DRY RUN — re-run with --apply to make changes."
    if find_restic; then echo "restic: $RESTIC ($("$RESTIC" version | head -1))"
    else echo "restic: missing -> winget install -e --id restic.restic --scope machine"; $APPLY && die "install restic first"; fi
    [[ -d /w ]] || die "W: (WD Elements) is not connected"
    # 1. password file
    if [[ -f $PWDIR_POSIX/password ]]; then echo "password file: exists"
    elif $APPLY; then
        read -rsp "New repository password (store it in Bitwarden too): " P1; echo
        read -rsp "Again: " P2; echo
        [[ -n $P1 && $P1 == "$P2" ]] || die "passwords empty or different"
        mkdir -p "$PWDIR_POSIX"; printf '%s' "$P1" >"$PWDIR_POSIX/password"; unset P1 P2
        icacls.exe 'C:\ProgramData\dalekanium\restic' /inheritance:r /grant:r 'Eduardo:(OI)(CI)R' 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' >/dev/null \
            || die "could not restrict permissions on the password folder"
        echo "password file: created and restricted to Eduardo/SYSTEM/Administrators"
    else echo "password file: would ask for the password and create $RESTIC_PASSWORD_FILE"; fi
    # 2. repository
    if [[ -f $REPO_POSIX/config ]]; then echo "repository: exists ($RESTIC_REPOSITORY)"
    elif $APPLY; then r init || die "restic init failed"
    else echo "repository: would run restic init at $RESTIC_REPOSITORY"; fi
    # 3. nightly task: S4U (runs without being signed in, no stored password), highest privileges
    #    (for VSS), wakes the PC, runs late if a start was missed, max 8 h, one instance.
    BASH_EXE='C:\Program Files\Git\bin\bash.exe'; SCRIPT=$(cygpath -m "$HERE/restic.sh")
    PS="\$a = New-ScheduledTaskAction -Execute '$BASH_EXE' -Argument '\"$SCRIPT\" nightly';
\$t = New-ScheduledTaskTrigger -Daily -At '$TASK_TIME';
\$p = New-ScheduledTaskPrincipal -UserId '$USERNAME' -LogonType S4U -RunLevel Highest;
\$s = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 8) -MultipleInstances IgnoreNew;
Register-ScheduledTask -TaskPath '\\dalekanium\\' -TaskName '$TASK' -Action \$a -Trigger \$t -Principal \$p -Settings \$s -Force | Out-Null"
    echo "task: \\dalekanium\\$TASK daily at $TASK_TIME, wakes the PC, runs: bash \"$SCRIPT\" nightly"
    if $APPLY; then powershell.exe -NoProfile -NonInteractive -Command "$PS" && echo "task: registered" || die "task registration failed"; fi
    echo; echo "Next: Bitdefender exception for W:\\restic-dalekanium; first backup (long) from an elevated Git Bash:"
    echo "  bash $(cygpath -m "$HERE/restic.sh") backup --dry-run   then   bash ... backup"
    ;;
backup)
    need_repo
    if [[ ${1:-} == --dry-run ]]; then do_backup --dry-run -v; else do_backup; fi
    ;;
nightly)
    mkdir -p "$LOGDIR"; LOG=$LOGDIR/restic-$(date +%Y%m%d-%H%M).log
    exec > >(tee -a "$LOG") 2>&1
    echo "== $(ts) nightly start"
    rc=0; fail() { echo "!! $*"; rc=1; }
    finish() {
        echo "== $(ts) nightly end, rc=$rc"
        echo "$(ts) $([[ $rc == 0 ]] && echo OK || echo FAIL) $(basename "$LOG")" >>"$LOGDIR/restic-last.txt"
        (( rc != 0 )) && eventcreate.exe /T ERROR /ID 100 /L APPLICATION /SO dalekanium-restic /D "restic nightly failed, see $(cygpath -w "$LOG")" >/dev/null 2>&1
        exit $rc
    }
    # keep Windows awake for as long as this script runs (released when it exits)
    WINPID=$(cat /proc/$$/winpid 2>/dev/null)
    [[ -n $WINPID ]] && powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
        -File "$(cygpath -w "$HERE/keepawake.ps1")" -ParentPid "$WINPID" >/dev/null 2>&1 &
    ( need_repo ) || { fail "repository, password or restic missing"; finish; }
    find_restic
    # wait (max 60 min) until Syncthing is idle with nothing left to fetch, after giving it 5 min to reconnect
    CFG=/c/Users/Eduardo/AppData/Local/Syncthing/config.xml
    KEY=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$CFG" 2>/dev/null | head -1)
    if [[ -n $KEY ]] && curl -s -m 5 -H "X-API-Key: $KEY" http://127.0.0.1:8384/rest/system/ping >/dev/null; then
        echo "$(ts) Syncthing up; waiting 5 min for peers, then for idle"; sleep 300
        for i in $(seq 1 120); do
            busy=0
            for f in synchro secreto; do
                st=$(curl -s -m 10 -H "X-API-Key: $KEY" "http://127.0.0.1:8384/rest/db/status?folder=$f")
                state=$(grep -o '"state": *"[^"]*"' <<<"$st" | sed 's/.*"\([^"]*\)"$/\1/')
                need=$(grep -o '"needTotalItems": *[0-9]*' <<<"$st" | grep -o '[0-9]*$')
                [[ $state == idle && ${need:-1} == 0 ]] || busy=1
            done
            (( busy == 0 )) && { echo "$(ts) Syncthing idle"; break; }
            (( i == 120 )) && echo "$(ts) Syncthing still busy after 60 min; backing up anyway"
            sleep 30
        done
    else echo "$(ts) Syncthing not reachable (not signed in?); backing up without waiting"; fi
    do_backup; brc=$?
    if (( brc == 3 )); then echo "!! backup complete but some files could not be read (see above); not counted as failure"
    elif (( brc != 0 )); then fail "backup failed (exit $brc)"; fi
    r forget --host DALEKANIUM --tag nightly "${KEEP[@]}" || fail "forget failed"
    if [[ $(date +%u) == 7 ]]; then
        r prune || fail "prune failed"
        r check --read-data-subset=5% || fail "check FAILED: repository damage suspected"
    fi
    finish
    ;;
status)
    need_repo
    r snapshots --compact | tail -15
    r stats --mode raw-data 2>/dev/null | grep -iE 'total size|snapshots'
    echo "-- last runs:"; grep -v OFFLINE "$LOGDIR/restic-last.txt" 2>/dev/null | tail -5 || echo "(none yet)"
    last=$(grep OFFLINE "$LOGDIR/restic-last.txt" 2>/dev/null | grep ' OK ' | tail -1)
    if [[ -n $last ]]; then
        age=$(( ( $(date +%s) - $(date -d "${last:0:19}" +%s) ) / 86400 ))
        echo "-- offline SSD: last copy $age day(s) ago$( (( age > 30 )) && echo '  <-- time to plug it in: restic.sh offline' )"
    else
        echo "-- offline SSD: never copied (restic.sh offline-init --apply, then restic.sh offline)"
    fi
    ;;
offline-init)
    APPLY=false; X=$OFF_DRIVE
    for a in "$@"; do
        case $a in --apply) APPLY=true ;; [A-Za-z]|[A-Za-z]:) X=${a:0:1} ;; *) die "usage: restic.sh offline-init [V:] [--apply]" ;; esac
    done
    X=${X^^}
    [[ " $OFF_SKIP " == *" ${X,,} "* ]] && die "$X: is one of DK's fixed drives, not the portable SSD"
    [[ -d /${X,,} ]] || die "$X: is not connected"
    is_admin || die "run offline-init from an elevated Git Bash"
    need_repo
    OFF_REPO="$X:\\$OFF_DIR"; OFF_POSIX="/${X,,}/$OFF_DIR"
    echo "offline repository: $OFF_REPO   (free on $X:: $(df -h "/${X,,}" | awk 'NR==2{print $4}'); W: holds $(du -sh "$REPO_POSIX" 2>/dev/null | cut -f1))"
    $APPLY || { echo "DRY RUN: would create it (own password, chunker parameters copied from W:). Re-run with --apply."; exit 0; }
    [[ -f $OFF_POSIX/config ]] && { echo "already initialised"; exit 0; }
    [[ -f $(cygpath -u "$OFF_PW") ]] || make_password "$OFF_PW"
    "$RESTIC" init -r "$OFF_REPO" --password-file "$OFF_PW" --from-repo "$RESTIC_REPOSITORY" \
        --from-password-file "$RESTIC_PASSWORD_FILE" --copy-chunker-params || die "restic init failed"
    echo "created. Next: bash restic.sh offline   (first copy: the whole repository, ~$(du -sh "$REPO_POSIX" 2>/dev/null | cut -f1))"
    ;;
offline)
    need_repo
    find_offline || die "no portable SSD with \\$OFF_DIR is connected (expected at ${OFF_DRIVE^^}:; first time: restic.sh offline-init --apply)"
    [[ -f $(cygpath -u "$OFF_PW") ]] || die "no password file $OFF_PW"
    mkdir -p "$LOGDIR"; LOG=$LOGDIR/restic-offline-$(date +%Y%m%d-%H%M).log
    exec > >(tee -a "$LOG") 2>&1
    echo "== $(ts) offline copy to $OFF_REPO"
    rc=0
    ro unlock >/dev/null 2>&1
    ro copy --from-repo "$RESTIC_REPOSITORY" --from-password-file "$RESTIC_PASSWORD_FILE" || { echo "!! copy failed"; rc=1; }
    if (( rc == 0 )); then
        ro forget --host DALEKANIUM --tag nightly "${KEEP[@]}" --prune || { echo "!! forget/prune failed"; rc=1; }
        ro check --read-data-subset=5% || { echo "!! check FAILED"; rc=1; }
    fi
    echo "== $(ts) offline end, rc=$rc"
    echo "$(ts) OFFLINE $([[ $rc == 0 ]] && echo OK || echo FAIL) $(basename "$LOG")" >>"$LOGDIR/restic-last.txt"
    (( rc == 0 )) && echo "Done. Eject the SSD (taskbar: Safely Remove Hardware) and unplug it."
    exit $rc
    ;;
offline-restore-test)
    find_offline || die "the portable SSD is not connected"
    export RESTIC_REPOSITORY="$OFF_REPO" RESTIC_PASSWORD_FILE="$OFF_PW"; REPO_POSIX=$OFF_POSIX
    ;&                                     # continue with restore-test, against the SSD
restore-test)
    need_repo; N=${1:-20}; T=$(mktemp -d)
    echo "listing the latest snapshot..."
    r ls --json latest >"$T/ls.json" || die "restic ls failed"
    STIME=$(head -1 "$T/ls.json" | grep -o '"time":"[^"]*"' | cut -d'"' -f4)
    grep '"type":"file"' "$T/ls.json" | grep -v '"size":[0-9]\{9,\}' | shuf -n "$N" \
        | grep -o '"path":"[^"]*"' | cut -d'"' -f4 >"$T/sample"
    ok=0; bad=0; changed=0
    while IFS= read -r p; do                # p like /M/Eduardo/x/y
        live="/${p:1:1}"; live="${live,,}${p:2}"          # -> /m/Eduardo/x/y for Git Bash
        if [[ ! -f $live || $(date -r "$live" +%s) -ge $(date -d "$STIME" +%s) ]]; then
            echo "  skipped (changed since the snapshot, or name not decodable): $p"; changed=$((changed+1)); continue; fi
        a=$(r dump latest "$p" | sha256sum | cut -c1-64); b=$(sha256sum <"$live" | cut -c1-64)
        if [[ $a == "$b" ]]; then ok=$((ok+1)); else echo "  MISMATCH: $p"; bad=$((bad+1)); fi
    done <"$T/sample"
    rm -rf "$T"
    echo "restore test: $ok identical, $bad mismatched, $changed skipped (changed since the snapshot of $STIME)"
    (( bad == 0 ))
    ;;
restic) need_repo; r "$@" ;;
*) sed -n '2,24p' "$0"; exit 1 ;;
esac
