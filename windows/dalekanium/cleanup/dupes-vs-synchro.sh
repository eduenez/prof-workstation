#!/usr/bin/env bash
# windows/dalekanium/cleanup/dupes-vs-synchro.sh — read-only. Finds files in M:\Eduardo, outside
# the synced folders, whose exact content (SHA-256) already exists inside M:\Eduardo\synchro.
# Those copies are safe to delete from M: (the content lives on in synchro, every Syncthing peer,
# and Restic). Run in Git Bash:  bash dupes-vs-synchro.sh      (roughly 10-30 minutes)
# Only same-size candidates are hashed, so most files are never read.
# Output: M:\Eduardo\win-inventory\dupes-<date>\
#   dupes.tsv        size  path-outside  path-in-synchro   (one line per redundant file)
#   dupes-by-dir.tsv bytes freed per top-level folder if all its duplicates were removed
set -u
BASE=/m/Eduardo
OUT="$BASE/win-inventory/dupes-$(date +%Y%m%d-%H%M)"; mkdir -p "$OUT"
W=$(mktemp -d)
SYNCED=(synchro secreto GoogleDrive Dropbox Tresorit repos win-inventory)
prune=(); for s in "${SYNCED[@]}"; do prune+=( -path "$BASE/$s" -o ); done

echo "1/4 listing synchro..."
find "$BASE/synchro" -type f -not -path '*/.stversions/*' -size +0 -printf '%s\t%p\n' >"$W/syn.tsv"
echo "2/4 listing the rest of M:\\Eduardo..."
find "$BASE" -mindepth 1 \( "${prune[@]}" -false \) -prune -o -type f -size +0 -printf '%s\t%p\n' 2>/dev/null >"$W/out.tsv"
# keep only sizes present on both sides
cut -f1 "$W/syn.tsv" | sort -u >"$W/s1"; cut -f1 "$W/out.tsv" | sort -u >"$W/s2"
comm -12 "$W/s1" "$W/s2" >"$W/common"
awk -F'\t' 'NR==FNR{c[$1];next} ($1 in c)' "$W/common" "$W/syn.tsv" >"$W/syn.cand"
awk -F'\t' 'NR==FNR{c[$1];next} ($1 in c)' "$W/common" "$W/out.tsv" >"$W/out.cand"
echo "   candidates: $(wc -l <"$W/out.cand") outside, $(wc -l <"$W/syn.cand") in synchro"
# batch the hashing (one sha256sum per thousands of files: process start-up is slow on Windows)
hashlist() {
    cut -f2 "$1" | tr '\n' '\0' | xargs -0 sha256sum 2>/dev/null \
      | sed -E 's/^\\?([0-9a-f]{64}) [ *](.*)$/\1\t\2/' >"$1.h0"
    awk -F'\t' 'BEGIN{OFS="\t"} NR==FNR{sz[$2]=$1; next} ($2 in sz){print $1, sz[$2], $2}' "$1" "$1.h0"
}
echo "3/4 hashing synchro candidates..."; hashlist "$W/syn.cand" | sort >"$W/syn.h"
echo "4/4 hashing outside candidates..."; hashlist "$W/out.cand" | sort >"$W/out.h"
# join on hash: outside file -> one synchro copy
join -t $'\t' -j 1 -o 1.2,1.3,2.3 "$W/out.h" <(sort -u -t $'\t' -k1,1 "$W/syn.h") \
  | sed "s#$BASE/##g" | sort -t $'\t' -k1,1nr >"$OUT/dupes.tsv"
awk -F'\t' 'BEGIN{OFS="\t"} {t=$2; sub(/\/.*/,"",t); B[t]+=$1; N[t]++} END{for(t in B) print B[t], N[t], t}' "$OUT/dupes.tsv" \
  | sort -t $'\t' -k1,1nr >"$OUT/dupes-by-dir.tsv"
tot=$(awk -F'\t' '{s+=$1} END{printf "%.1f GB", s/1073741824}' "$OUT/dupes.tsv")
rm -rf "$W"
echo "done: $(wc -l <"$OUT/dupes.tsv") redundant files, $tot reclaimable -> $(cygpath -w "$OUT")"
