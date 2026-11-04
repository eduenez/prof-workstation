#!/usr/bin/env bash
# windows/dalekanium/cleanup/m-usage.sh — read-only space report for the M: cleanup.
# Run in Git Bash (no admin needed):  bash m-usage.sh            (whole M:\Eduardo)
#                                     bash m-usage.sh Downloads  (drill into one folder)
# Writes M:\Eduardo\win-inventory\m-usage-<date>\ (outside git):
#   by-top.tsv     one row per entry directly under M:\Eduardo (synced folders excluded):
#                  size, files, newest file date, top-3 extensions by size
#   by-ext.tsv     totals per file extension over the same area
#   largest.tsv    the 400 largest files in that area
#   synced.tsv     sizes of the synced folders (left alone by the cleanup)
#   m-root.tsv     sizes of everything at the root of M: (WSL disk, UTSA OneDrive, ...)
set -u
BASE=/m/Eduardo
SUB=${1:-}
ROOT=$BASE${SUB:+/$SUB}
OUT="$BASE/win-inventory/m-usage-$(date +%Y%m%d-%H%M)${SUB:+-${SUB//[\/ ]/_}}"
mkdir -p "$OUT"
FILES=$(mktemp)            # scratch list, kept out of the scanned tree
SYNCED=(synchro secreto GoogleDrive Dropbox Tresorit repos)
human() { awk -F'\t' -v c="$1" 'BEGIN{OFS="\t"} {b=$c; u="B"; split("KB MB GB TB",U," ");
          for(i=1;b>=1024 && i<=4;i++){b/=1024; u=U[i]} $c=sprintf("%.1f %s",b,u); print}'; }

echo "scanning $ROOT (this can take several minutes)..."
prune=(); for s in "${SYNCED[@]}"; do prune+=( -path "$ROOT/$s" -o ); done
find "$ROOT" -mindepth 1 \( "${prune[@]}" -false \) -prune -o -type f -printf '%P\t%s\t%T@\n' 2>/dev/null >"$FILES"

# per top-level entry
awk -F'\t' 'BEGIN{OFS="\t"}
  { top=$1; sub(/\/.*/,"",top); if (index($1,"/")==0) top="(loose files)";
    n=split($1,p,"/"); f=tolower(p[n]); e=(f ~ /\./)? f : ""; sub(/.*\./,"",e); if(e=="") e="(none)";
    B[top]+=$2; N[top]++; if($3>M[top]) M[top]=$3; X[top SUBSEP e]+=$2 }
  END{ for(t in B){ s="";
         for(k in X){ split(k,q,SUBSEP); if(q[1]==t) E[q[2]]=X[k] }
         for(j=1;j<=3;j++){ best=""; bv=-1; for(e in E) if(E[e]>bv){bv=E[e]; best=e}
                            if(best!=""){ s=s (s?" ":"") best; delete E[best] } }
         for(e in E) delete E[e];
         print B[t], N[t], strftime("%Y-%m-%d",M[t]), t, s } }' "$FILES" \
  | sort -t$'\t' -k1,1nr | human 1 | { printf 'size\tfiles\tnewest\tentry\ttop extensions\n'; cat; } >"$OUT/by-top.tsv"

# per extension
awk -F'\t' 'BEGIN{OFS="\t"} { n=split($1,p,"/"); f=tolower(p[n]); e=(f ~ /\./)? f : ""; sub(/.*\./,"",e); if(e=="") e="(none)";
  B[e]+=$2; N[e]++ } END{ for(e in B) print B[e], N[e], e }' "$FILES" \
  | sort -t$'\t' -k1,1nr | human 1 | { printf 'size\tfiles\textension\n'; cat; } >"$OUT/by-ext.tsv"

# largest files
sort -t$'\t' -k2,2nr "$FILES" | head -400 \
  | awk -F'\t' 'BEGIN{OFS="\t"} {print $2, strftime("%Y-%m-%d",$3), $1}' | human 1 \
  | { printf 'size\tdate\tpath\n'; cat; } >"$OUT/largest.tsv"

# synced folders and the root of M: (whole-tree run only)
if [[ -z $SUB ]]; then
for s in "${SYNCED[@]}"; do [[ -d $ROOT/$s ]] && du -sb "$ROOT/$s" 2>/dev/null; done \
  | awk -F'\t' 'BEGIN{OFS="\t"} {sub(/.*\//,"",$2); print $1,$2}' | human 1 >"$OUT/synced.tsv"
for e in /m/*; do du -sb "$e" 2>/dev/null; done | sort -nr \
  | awk -F'\t' 'BEGIN{OFS="\t"} {sub(/^\/m\//,"",$2); print $1,$2}' | human 1 >"$OUT/m-root.tsv"
df -h /m | tail -1 >"$OUT/df.txt"
fi

rm -f "$FILES"
echo "done: $(cygpath -w "$OUT")"
