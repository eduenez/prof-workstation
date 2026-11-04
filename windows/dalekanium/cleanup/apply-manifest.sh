#!/usr/bin/env bash
# windows/dalekanium/cleanup/apply-manifest.sh — carries out manifest.tsv (from build-manifest.sh).
#   bash apply-manifest.sh                    dry run: counts, sizes, first lines; changes nothing
#   bash apply-manifest.sh --apply delete     delete the "delete" rows from M:
#   bash apply-manifest.sh --apply move-G     copy "move-G" rows to G:\M-Eduardo, verify, remove from M:
# Safety:
#   * refuses to delete or move anything unless the W: snapshot finished
#     (W:\M-Eduardo-snapshot-2026-11\.snapshot-complete, written by m-snapshot.cmd);
#   * a dup-of-synchro row is deleted only if its synchro twin still exists with the same size;
#   * move-G removes the M: copy only after the G: copy exists with the same size and SHA-256;
#   * every action is logged in M:\Eduardo\win-inventory\cleanup\apply-<date>.log.
set -u
BASE=/m/Eduardo
OUT=$BASE/win-inventory/cleanup
MAN=$OUT/manifest.tsv
SNAP=/w/M-Eduardo-snapshot-2026-11
GDEST=/g/M-Eduardo
APPLY=false; [[ ${1:-} == --apply ]] && { APPLY=true; shift; }
WHAT=${1:-}
[[ -f $MAN ]] || { echo "no manifest: run build-manifest.sh first" >&2; exit 1; }
DUPES=$(ls -d "$BASE"/win-inventory/dupes-*/dupes.tsv 2>/dev/null | sort | tail -1)

gb() { awk -v b="$1" 'BEGIN{printf "%.1f GB", b/2^30}'; }
total() { awk -F'\t' -v a="$1" '$1==a{s+=$3} END{print s+0}' "$MAN"; }
count() { awk -F'\t' -v a="$1" '$1==a{n++} END{print n+0}' "$MAN"; }

if ! $APPLY; then
    echo "DRY RUN (nothing changes). Manifest: $MAN"
    for a in delete move-G keep; do printf '  %-7s %7d files  %s\n' "$a" "$(count $a)" "$(gb "$(total $a)")"; done
    echo "  G: free now: $(df -h /g 2>/dev/null | awk 'NR==2{print $4}')   (move-G needs $(gb "$(total move-G)"))"
    [[ -f $SNAP/.snapshot-complete ]] && echo "  W: snapshot: complete" || echo "  W: snapshot: NOT complete -> run m-snapshot.cmd first"
    echo; echo "first delete rows:"; awk -F'\t' '$1=="delete"' "$MAN" | head -15 | cut -f2- | sed 's/^/  /'
    echo; echo "first move-G rows:"; awk -F'\t' '$1=="move-G"' "$MAN" | head -15 | cut -f2- | sed 's/^/  /'
    exit 0
fi
case $WHAT in delete|move-G) ;; *) echo "usage: --apply delete | --apply move-G" >&2; exit 1;; esac
[[ -f $SNAP/.snapshot-complete ]] || { echo "W: snapshot not complete ($SNAP): run m-snapshot.cmd first" >&2; exit 1; }
LOG=$OUT/apply-$(date +%Y%m%d-%H%M%S).log
echo "logging to $LOG"
done_n=0; done_b=0; skip=0

if [[ $WHAT == delete ]]; then
    declare -A twin=()
    if [[ -n $DUPES ]]; then
        while IFS=$'\t' read -r sz p q; do twin["$p"]="$q"; done <"$DUPES"
    fi
    while IFS=$'\t' read -r act rule sz p; do
        [[ $act == delete ]] || continue
        f="$BASE/$p"; [[ -f $f ]] || continue
        if [[ $rule == dup-of-synchro* ]]; then
            q=${twin["$p"]:-}
            if [[ -z $q || ! -f $BASE/$q || $(stat -c %s "$BASE/$q") != "$sz" ]]; then
                echo "SKIP no-twin  $p" >>"$LOG"; skip=$((skip+1)); continue
            fi
        fi
        if rm -f -- "$f"; then echo "DEL  $sz  $p" >>"$LOG"; done_n=$((done_n+1)); done_b=$((done_b+sz))
        else echo "FAIL $p" >>"$LOG"; skip=$((skip+1)); fi
    done <"$MAN"
else
    [[ -d /g ]] || { echo "G: is not connected" >&2; exit 1; }
    need=$(total move-G); free=$(df -B1 /g | awk 'NR==2{print $4}')
    (( need < free )) || { echo "G: has $(gb "$free") free, move-G needs $(gb "$need")" >&2; exit 1; }
    while IFS=$'\t' read -r act rule sz p; do
        [[ $act == move-G ]] || continue
        f="$BASE/$p"; [[ -f $f ]] || continue
        d="$GDEST/$p"; mkdir -p "$(dirname "$d")"
        if cp -p -- "$f" "$d" && [[ $(stat -c %s "$d") == "$sz" ]] \
           && [[ $(sha256sum <"$f" | cut -c1-64) == $(sha256sum <"$d" | cut -c1-64) ]]; then
            rm -f -- "$f"; echo "MOVE $sz  $p" >>"$LOG"; done_n=$((done_n+1)); done_b=$((done_b+sz))
        else
            echo "FAIL $p (copy or verify)" >>"$LOG"; skip=$((skip+1))
        fi
        (( done_n % 200 == 0 )) && echo "  ... $done_n files, $(gb $done_b)"
    done <"$MAN"
fi
# remove directories left empty by this run (never the top-level folders themselves)
find "$BASE" -mindepth 2 -depth -type d -empty \
     -not -path "$BASE/synchro/*" -not -path "$BASE/secreto/*" -not -path "$BASE/GoogleDrive/*" \
     -not -path "$BASE/Dropbox/*" -not -path "$BASE/Tresorit/*" -not -path "$BASE/private/*" \
     -not -path "$BASE/repos/*" -delete 2>/dev/null
echo "done: $done_n files, $(gb $done_b) ($WHAT); $skip skipped/failed -> see log"
