#!/usr/bin/env bash
# 15-detex — Build a patched detex into ~/.local/bin.
# TeX Live's detex (OpenDetex 2.8.11) segfaults on any \includeonly when run
# with -n, which Recoll's TeX filter always passes, so such files index with
# no text. Upstream fix: https://github.com/pkubowicz/opendetex/pull/91
# Skips itself once the detex on PATH no longer crashes.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

OPENDETEX_REPO="https://github.com/pkubowicz/opendetex.git"
OPENDETEX_REV="5a0c6203f8d004bfcbcaa9e608215a0cc5daf3e5"   # master, 2026-02-20
PATCH="$REPO_DIR/patches/opendetex-includeonly.patch"
DEST="$HOME/.local/bin"

# Succeeds if the given detex survives the \includeonly crash case.
_detex_ok() {
    local tmp rc
    tmp="$(mktemp -d)"
    printf '\\includeonly{a}\nok\n' > "$tmp/t.tex"
    "$1" -n "$tmp/t.tex" &>/dev/null
    rc=$?
    rm -rf "$tmp"
    [[ $rc -lt 128 ]]
}

_build_detex() {
    local current
    current="$(PATH="$DEST:$PATH" command -v detex)"
    if [[ -n "$current" ]] && _detex_ok "$current"; then
        info "detex at $current is not affected — nothing to do."
        return 0
    fi
    for cmd in git make cc flex; do
        command_exists "$cmd" || { err "$cmd not found (Linux: apt install flex build-essential)."; return 1; }
    done

    local src
    src="$(mktemp -d)"
    info "Building patched OpenDetex (${OPENDETEX_REV:0:7})..."
    git clone -q "$OPENDETEX_REPO" "$src" \
        && git -C "$src" checkout -q "$OPENDETEX_REV" \
        && git -C "$src" apply "$PATCH" \
        && make -C "$src" detex DEFS=-DHAVE_STRING_H LEXLIB= >/dev/null \
        && _detex_ok "$src/detex" \
        && mkdir -p "$DEST" \
        && install -m 755 "$src/detex" "$DEST/detex"
    local rc=$?
    rm -rf "$src"
    [[ $rc -eq 0 ]] && info "Installed $DEST/detex."
    return $rc
}

run_step "Patched detex" _build_detex
summary_report
