#!/usr/bin/env bash
# 19-qemacs — Build QEmacs (github.com/qemacs/qemacs) into ~/.local: the light, instant-start editor
# that dotfiles/zshrc makes $EDITOR / $VISUAL (`qe -nw`), so no program ever drops you into vi.
# Distro packages are years old (Debian/Ubuntu ship 0.4), so it is built from a pinned commit.
#   Linux/WSL: X11 build when the X11 headers are present (apt-packages.txt lists them):
#              `qe` opens an X window if $DISPLAY is set (WSLg sets it), `qe -nw` stays in the terminal.
#   macOS:     terminal build (no X11 headers without XQuartz).
# Re-running is a no-op until QEMACS_REV changes.  Uninstall: make uninstall prefix=~/.local.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

QEMACS_REPO="https://github.com/qemacs/qemacs.git"
QEMACS_REV="2107926a07ff8553e7633bcee306779d62c496a5"   # 6.5.2, 2026-10-09
PREFIX="$HOME/.local"
STAMP="$PREFIX/share/qe/.build-rev"

_build_qemacs() {
    if [[ -x "$PREFIX/bin/qemacs" && "$(cat "$STAMP" 2>/dev/null)" == "$QEMACS_REV" ]]; then
        info "QEmacs ${QEMACS_REV:0:7} already installed in $PREFIX/bin — nothing to do."
        return 0
    fi
    for cmd in git make cc; do
        command_exists "$cmd" || { err "$cmd not found (Linux: apt install build-essential; macOS: xcode-select --install)."; return 1; }
    done
    if [[ $OS == Linux && ! -f /usr/include/X11/Xlib.h ]]; then
        warn "No X11 headers (apt install libx11-dev libxext-dev libxrender-dev libxv-dev): terminal-only build."
    fi

    local src
    src="$(mktemp -d)"
    info "Building QEmacs ${QEMACS_REV:0:7}..."
    # configure writes its objects in the current directory, hence the cd.
    git clone -q "$QEMACS_REPO" "$src" \
        && git -C "$src" checkout -q "$QEMACS_REV" \
        && (cd "$src" && ./configure --prefix="$PREFIX" >/dev/null && make -j4 >/dev/null 2>&1) \
        && [[ $("$src/qe" -V 2>&1) == *QEmacs* ]] \
        && make -C "$src" install >/dev/null \
        && echo "$QEMACS_REV" > "$STAMP"
    local rc=$?
    rm -rf "$src"
    if [[ $rc -eq 0 ]]; then
        info "Installed $PREFIX/bin/qe ($("$PREFIX/bin/qe" -V 2>&1 | sed -n 1p)); config file: ~/.qe/config."
    else
        err "QEmacs build failed — rerun by hand to see why: git clone $QEMACS_REPO; ./configure; make"
    fi
    return $rc
}

run_step "QEmacs" _build_qemacs
summary_report
