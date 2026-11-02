#!/usr/bin/env bash
# windows/prewipe-backup.sh — save whatever on C: could matter, before the clean install.
#
# Two independent layers, both written to the external F: drive:
#   copy   browsable copy of C:\Users\Eduardo (minus caches/temp/cloud folders),
#          a few hand-made folders at the root of C:, and `wsl --export` of each distro
#   image  full Windows system image of C: (built-in wbadmin; Windows 10/11 Pro).
#          Produces a .vhdx that Windows 11 can attach read-only later
#          (Disk Management -> Action -> Attach VHD), so any forgotten file is still reachable.
#
# Usage, from an ELEVATED Cygwin/MSYS2 bash:
#   bash prewipe-backup.sh copy      # ~minutes to an hour, mostly the WSL exports
#   bash prewipe-backup.sh image     # ~1-3 hours for ~375 GB
#   bash prewipe-backup.sh both
# Optional 2nd argument: destination (default F:\dalekanium-prewipe).
# Read-only on C:; safe to re-run (robocopy only copies what changed).

set -u
MODE=${1:-}
DEST_W=${2:-'F:\dalekanium-prewipe'}
case $MODE in copy|image|both) ;; *) sed -n '2,20p' "$0"; exit 1;; esac

if command -v cygpath >/dev/null 2>&1; then unixpath() { cygpath -u "$1"; }
else echo "Run from Cygwin or MSYS2 bash." >&2; exit 1; fi
net.exe session >/dev/null 2>&1 || { echo "Needs an elevated (Run as administrator) terminal." >&2; exit 1; }

DEST=$(unixpath "$DEST_W"); mkdir -p "$DEST" || exit 1
LOG_W="$DEST_W\\robocopy.log"
note() { printf '%s  %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$DEST/_prewipe.log"; }

# rcopy SRC_W DEST_SUBDIR [extra robocopy args...]   (robocopy exit codes < 8 mean success)
rcopy() {
    local src=$1 dst="$DEST_W\\$2"; shift 2
    [[ -d $(unixpath "$src") ]] || { note "absent  $src"; return; }
    note "copy    $src"
    robocopy.exe "$src" "$dst" /E /XJ /COPY:DAT /DCOPY:DAT /R:1 /W:1 /MT:8 /NP /NFL /NDL /LOG+:"$LOG_W" "$@" >/dev/null
    local r=$?
    (( r < 8 )) && note "ok      $src (robocopy $r)" || note "FAIL    $src (robocopy $r; see robocopy.log)"
}

do_copy() {
    note "=== copy -> $DEST_W"
    # The whole profile, minus regenerable or cloud-held bulk. /XJ skips the legacy junctions
    # ("Application Data", "My Documents", ...) that would otherwise loop.
    rcopy 'C:\Users\Eduardo' 'Users-Eduardo' \
        /XD Temp INetCache INetCookies "Code Cache" GPUCache Cache cache2 CachedData \
            "Service Worker" ShaderCache D3DSCache CrashDumps IconCache thumbcache \
            iCloudDrive OneDrive "Creative Cloud Files" "Downloaded Installations" Docker \
        /XF NTUSER.DAT* ntuser.dat.LOG* ntuser.ini UsrClass.dat* "*.ost" ext4.vhdx "*.tmp"
    # Hand-made folders at the root of C: (custom TeX tree, file-manager configs, etc.)
    for d in localtexmf totalcmd FarManager MangaHumbleBundle PanoptoRecorder temp; do
        rcopy "C:\\$d" "C-root\\$d"
    done
    rcopy 'C:\cygwin64\home' 'C-root\cygwin64-home'
    rcopy 'C:\cygwin64\etc'  'C-root\cygwin64-etc'

    # WSL distros as tarballs (restorable with `wsl --import`, or just untar to read files)
    mkdir -p "$DEST/wsl"
    wsl.exe --shutdown >/dev/null 2>&1
    sed -e '1d' -e 's/^[* \t]*//' -e 's/[ \t].*//' -e '/^$/d' \
        < <(wsl.exe --list --verbose 2>&1 | tr -d '\0\r') | while IFS= read -r d; do
        note "export  WSL $d"
        if wsl.exe --export "$d" "$DEST_W\\wsl\\$d.tar" </dev/null >/dev/null 2>&1; then note "ok      WSL $d"
        else note "FAIL    WSL $d"; fi
    done
    note "copy done: $(du -sh "$DEST" 2>/dev/null | cut -f1) in $DEST_W"
}

do_image() {
    local drive=${DEST_W%%\\*}            # F:
    note "=== system image of C: -> $drive (wbadmin)"
    wbadmin.exe start backup -backupTarget:"$drive" -include:C: -allCritical -quiet \
        && note "image ok: $drive\\WindowsImageBackup\\$(hostname)" \
        || note "FAIL    wbadmin (see Event Viewer > Applications and Services > Microsoft > Windows > Backup)"
}

[[ $MODE == copy  || $MODE == both ]] && do_copy
[[ $MODE == image || $MODE == both ]] && do_image
note "log: $DEST_W\\_prewipe.log"
