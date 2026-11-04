#!/usr/bin/env bash
# windows/dalekanium/cleanup/build-manifest.sh — read-only. Classifies every file in M:\Eduardo
# outside the synced folders by rule and writes a manifest to review before anything changes.
#   bash build-manifest.sh            (Git Bash; a few minutes)
# Output (outside git: file names can be private): M:\Eduardo\win-inventory\cleanup\
#   manifest.tsv   action  rule  bytes  path            one line per file
#   summary.txt    GB per action and rule, top folders per rule, and sample paths per rule
# Actions:  delete   (gone from M:; still in the W: snapshot)
#           move-G   (copied to G:\M-Eduardo, verified, then removed from M:)
#           keep     (stays on M:; second copy to G: later, space permitting)
# To change decisions, edit overrides.tsv in the same folder (prefix<TAB>action, longest prefix
# wins, e.g. "Downloads/Calculators<TAB>keep") and re-run this script. apply-manifest.sh acts.
set -u
BASE=/m/Eduardo
OUT=$BASE/win-inventory/cleanup; mkdir -p "$OUT"
DUPES=$(ls -d "$BASE"/win-inventory/dupes-*/dupes.tsv 2>/dev/null | sort | tail -1)
[[ -n $DUPES ]] || { echo "no dupes-*/dupes.tsv: run dupes-vs-synchro.sh first" >&2; exit 1; }
[[ -f $OUT/overrides.tsv ]] || printf '# prefix<TAB>action (delete | move-G | keep); longest prefix wins\n' >"$OUT/overrides.tsv"
SYNCED=(synchro secreto GoogleDrive Dropbox Tresorit private repos)
prune=(); for s in "${SYNCED[@]}"; do prune+=( -path "$BASE/$s" -o ); done
LIST=$(mktemp)
echo "listing..."
find "$BASE" -mindepth 1 \( "${prune[@]}" -false \) -prune -o -type f -printf '%s\t%P\n' 2>/dev/null >"$LIST"

echo "classifying $(wc -l <"$LIST") files (duplicates from $DUPES)..."
awk -F'\t' -v OFS='\t' -v ovf="$OUT/overrides.tsv" '
FILENAME==ARGV[1] { dup[$2]=1; next }                       # dupes.tsv: size, outside path, synchro path
function low(s) { return tolower(s) }
function rule(p,   lp, f, e) {
  lp=low(p); n=split(lp,a,"/"); f=a[n]; e=(f ~ /\./)? f : ""; sub(/.*\./,"",e)
  if (p in dup) return "delete dup-of-synchro"
  # superseded inventory run (kept: 1853 with the driver export, 2343 the complete one)
  if (lp ~ /^win-inventory\/dalekanium-20261101-2222\//) return "delete superseded-inventory"
  if (lp ~ /^win-inventory\//) return "keep inventory"
  # virtual machines
  if (lp ~ /^(\.virtualbox|virtualboxes|windowsxpmode|virtual machines)\// || lp ~ /^downloads\/(winxp_vm_files|colinux)\// \
      || lp ~ /^documents\/my virtual machines\// || e ~ /^(vdi|vhd|vhdx|vmdk|dsk|vsv|vmcx|vmrs)$/) return "delete old-vm"
  # video games, installers, ROMs, emulators: keep, off M:
  if (lp ~ /^(goggames|games|mame|visualboy)\// \
      || lp ~ /^downloads\/(games|psp|gog|emulators|nintendo64roms)\// \
      || lp ~ /^downloads\/[^\/]*(ddsetup|ddmf|scumm|snes9x|zsnes|masterboy|emumaster|gpsp|ccs64|vice|steelstorm)[^\/]*(\/|$)/ \
      || lp ~ /^documents\/(gog\.com downloads|media go|visualboy|project64)\// \
      || (lp ~ /^downloads\/[^\/]*$/ && f ~ /^setup_.*\.(exe|bin)$/) \
      || e ~ /^(gba|gbc|nes|smc|sfc|smd|n64|z64|v64|pbp|iso9660)$/) {
        if (lp ~ /^(goggames)\// || lp ~ /^documents\/gog\.com downloads\// || lp ~ /^downloads\/gog\// || f ~ /^setup_.*\.(exe|bin)$/)
             return "move-G game-gog-redownloadable"
        return "move-G game-or-rom" }
  # obsolete software installs and their caches
  if (lp ~ /^(anaconda3|enthought|enthought32|cygwin|adobe acrobat|openoffice4\.0\.1installationfiles|chezscheme|leo-4\.11-final|leo5\.0-final|\.anaconda|\.conda)\// \
      || lp ~ /^downloads\/(octave-[^\/]*|mit-scheme[^\/]*|pari-2[^\/]*|gambc[^\/]*|leo-editor|gambitscheme[^\/]*|ffmpeg-[^\/]*|nano-[^\/]*|xpdf-[^\/]*|pdftk-[^\/]*)\// ) return "delete obsolete-software"
  if (lp ~ /^itunes\// && e ~ /^(ipa|7z|itc2|ipsw)$/) return "delete obsolete-ios-apps"
  # installers, drivers and setup leftovers in Downloads (documents, archives, media are NOT matched)
  if (lp ~ /^downloads\// && e ~ /^(exe|msi|msp|msu|cab|iso|img|dmg|pkg|rpm|deb|run|dll|sys|inf|cat|cpl|ocx|dl_|ch_|ex_|sy_|drv|bin)$/) return "delete installer-or-driver"
  if (lp !~ /\// && e ~ /^(exe|msi|iso|img)$/) return "delete installer-or-driver"
  return "keep other"
}
BEGIN { while ((getline l < ovf) > 0) { if (l ~ /^#/ || l == "") continue; split(l,o,"\t"); ov[o[1]]=o[2] } }
{ r=rule($2); act=r; sub(/ .*/,"",act); rn=r; sub(/^[^ ]* /,"",rn)
  best=""; for (k in ov) if (index($2,k)==1 && length(k)>length(best)) best=k
  if (best!="") { act=ov[best]; rn=rn "+override" }
  print act, rn, $1, $2 }' "$DUPES" "$LIST" >"$OUT/manifest.tsv"
rm -f "$LIST"

{
  echo "manifest: $(cygpath -w "$OUT/manifest.tsv" 2>/dev/null || echo "$OUT/manifest.tsv")  ($(date '+%F %T'))"
  echo; echo "== GB by action"
  awk -F'\t' '{B[$1]+=$3; N[$1]++} END{for(a in B) printf "%8.1f GB  %7d files  %s\n", B[a]/2^30, N[a], a}' "$OUT/manifest.tsv" | sort -k1,1nr
  echo; echo "== GB by action / rule"
  awk -F'\t' '{k=$1" / "$2; B[k]+=$3; N[k]++} END{for(k in B) printf "%8.1f GB  %7d files  %s\n", B[k]/2^30, N[k], k}' "$OUT/manifest.tsv" | sort -k1,1nr
  echo; echo "== top folders per action / rule (2 levels)"
  awk -F'\t' '{n=split($4,p,"/"); d=(n>2)? p[1]"/"p[2] : (n==2? p[1] : "(loose)"); k=$1" / "$2"\t"d; B[k]+=$3}
       END{for(k in B) printf "%.2f\t%s\n", B[k]/2^30, k}' "$OUT/manifest.tsv" | sort -t$'\t' -k1,1nr | head -80 \
    | awk -F'\t' '{printf "%7.2f GB  %-40s %s\n", $1, $2, $3}'
  echo; echo "== samples (up to 12 random files per rule)"
  for r in $(cut -f1,2 "$OUT/manifest.tsv" | sort -u | tr '\t' '|'); do
    echo "-- ${r//|/ / }"
    awk -F'\t' -v k="$r" '($1"|"$2)==k {print $4}' "$OUT/manifest.tsv" | shuf -n 12 | sed 's/^/     /'
  done
} >"$OUT/summary.txt"
sed -n '1,40p' "$OUT/summary.txt"
echo "... full summary: $(cygpath -w "$OUT/summary.txt" 2>/dev/null || echo "$OUT/summary.txt")"
