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
    # Batched: a few hundred files per rm/stat process (one process per file is ~30 files/s in Git Bash).
    TMP=$(mktemp -d); X=(xargs -0 -r -s 20000)
    abs() { sed "s|^|$BASE/|" | tr '\n' '\0'; }            # relative paths -> NUL-separated absolute
    awk -F'\t' -v OFS='\t' 'FILENAME==ARGV[1] { tw[$2]=$3; next }
        $1=="delete" && $4 !~ /^win-inventory\/(cleanup|dupes-)/ { print $2, $3, $4, (($4 in tw)? tw[$4] : "") }' "${DUPES:-/dev/null}" "$MAN" >"$TMP/rows"
    echo "checking which of $(wc -l <"$TMP/rows") delete rows still exist..."
    cut -f3 "$TMP/rows" | abs | "${X[@]}" stat -c '%n' 2>/dev/null | sed "s|^$BASE/||" >"$TMP/exist"
    echo "checking synchro twins..."
    awk -F'\t' '$1 ~ /^dup-of-synchro/ && $4 != "" {print $4}' "$TMP/rows" | sort -u | abs \
        | "${X[@]}" stat -c $'%s\t%n' 2>/dev/null | sed "s|\t$BASE/|\t|" >"$TMP/twins"
    awk -F'\t' -v OFS='\t' -v lg="$LOG" '
        FILENAME==ARGV[1] { ex[$0]=1; next }
        FILENAME==ARGV[2] { tsz[$2]=$1; next }
        !($3 in ex) { next }
        $1 ~ /^dup-of-synchro/ && (!($4 in tsz) || tsz[$4] != $2) { print "SKIP no-twin  " $3 >>lg; next }
        { print $2, $3 }' "$TMP/exist" "$TMP/twins" "$TMP/rows" >"$TMP/go"
    skip=$(grep -c '^SKIP' "$LOG" 2>/dev/null); skip=${skip:-0}
    n=$(wc -l <"$TMP/go")
    echo "deleting $n files, $(gb "$(awk -F'\t' '{s+=$1} END{print s+0}' "$TMP/go")") ($skip dup rows skipped: twin missing or different size)"
    cut -f2 "$TMP/go" | split -l 10000 - "$TMP/chunk."
    i=0; for c in "$TMP"/chunk.*; do
        [[ -f $c ]] || continue
        abs <"$c" | "${X[@]}" rm -f --
        i=$(( i + $(wc -l <"$c") )); echo "  ... $i / $n"
    done
    cut -f2 "$TMP/go" | abs | "${X[@]}" stat -c '%n' 2>/dev/null | sed "s|^$BASE/||" >"$TMP/left"
    read -r done_n done_b f < <(awk -F'\t' -v lg="$LOG" 'FILENAME==ARGV[1] { left[$0]=1; next }
        ($2 in left) { print "FAIL " $2 >>lg; f++; next }
        { print "DEL  " $1 "  " $2 >>lg; n++; b+=$1 } END { print n+0, b+0, f+0 }' "$TMP/left" "$TMP/go")
    skip=$((skip + f)); rm -rf "$TMP"
else
    [[ -d /g ]] || { echo "G: is not connected" >&2; exit 1; }
    need=$(total move-G); free=$(df -B1 /g | awk 'NR==2{print $4}')
    (( need < free )) || { echo "G: has $(gb "$free") free, move-G needs $(gb "$need")" >&2; exit 1; }
    while IFS=$'\t' read -r act rule sz p; do
        [[ $act == move-G ]] || continue
        [[ $p == win-inventory/cleanup/* || $p == win-inventory/dupes-* ]] && continue   # never touch our own inputs
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
