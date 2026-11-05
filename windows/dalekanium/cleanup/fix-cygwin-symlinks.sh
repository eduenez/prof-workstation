#!/usr/bin/env bash
# windows/dalekanium/cleanup/fix-cygwin-symlinks.sh — one-off (2026-11-05): old Cygwin symlinks
# (Linux-style reparse points) that restic reports as "unsupported file type irregular".
#   bash fix-cygwin-symlinks.sh            dry run
#   bash fix-cygwin-symlinks.sh --apply
# Everything removed here is also in W:\M-Eduardo-snapshot-2026-11.
set -u
APPLY=false; [[ ${1:-} == --apply ]] && APPLY=true
B=/m/Eduardo
run() { echo "  $*"; $APPLY && { "$@" || echo "    !! failed"; }; }
$APPLY || echo "DRY RUN (re-run with --apply)"

echo "1. delete leftovers of trees the cleanup already emptied (only links and folders remain)"
for d in "$B/ChezScheme" "$B/Downloads/pari-2.5.3"; do
    [[ -e $d ]] || { echo "  (gone) $d"; continue; }
    n=$(find "$d" -type f | wc -l); echo "  $d: $n regular files left"
    (( n == 0 )) && run rm -rf -- "$d" || echo "  !! kept: has regular files, check by hand"
done

echo "2. exam scripts: replace broken links into the old Dropbox path with copies from Dropbox-old-local"
E="$B/Documents/MAT-3013-001-2020-3_MidtermExam"
for f in catsplitter.pl feedbackfiles.awk fnabridger.pl fnexpander.pl txtrenamer.pl; do
    l="$E/$f"; [[ -L $l ]] || { echo "  (not a link) $l"; continue; }
    t=$(readlink "$l"); src=${t/\/m\/Eduardo\/Dropbox\//$B\/Dropbox-old-local\/}
    if [[ -f $src ]]; then run rm -f -- "$l"; run cp -p -- "$src" "$l"
    else echo "  !! source not found for $f ($src): left as is"; fi
done

echo "3. oh-my-zsh: recreate as native Windows symlinks (Developer Mode allows it without admin)"
while IFS=$'\t' read -r l t; do
    [[ -L $l ]] || continue
    run rm -f -- "$l"
    $APPLY && { (cd "$(dirname "$l")" && MSYS=winsymlinks:nativestrict ln -s -- "$t" "$(basename "$l")") || echo "    !! ln failed"; } \
           || echo "  MSYS=winsymlinks:nativestrict ln -s $t $(basename "$l")   (in $(dirname "$l"))"
done <<LIST
$B/.oh-my-zsh/plugins/go/go.plugin.zsh	../golang/golang.plugin.zsh
$B/.oh-my-zsh/plugins/gradle/_gradle	gradle.plugin.zsh
$B/.oh-my-zsh/plugins/gradle/_gradlew	gradle.plugin.zsh
$B/.oh-my-zsh/plugins/per-directory-history/per-directory-history.plugin.zsh	per-directory-history.zsh
LIST

echo "4. self-referencing link in Tresorit's old trash"
l="$B/BACKUPS/private/.tresorit/Trash/security/gnupg/.gnupg"; [[ -L $l ]] && run rm -f -- "$l"

echo; echo "Remaining symlinks outside synchro (should be only .emacs.d and the oh-my-zsh ones):"
$APPLY && find "$B" -path "$B/synchro" -prune -o -type l -print 2>/dev/null
