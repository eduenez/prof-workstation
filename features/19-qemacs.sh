#!/usr/bin/env bash
# 19-qemacs — Build QEmacs (github.com/qemacs/qemacs) into ~/.local: the light, instant-start editor
# that dotfiles/zshrc makes $EDITOR / $VISUAL (`qe -nw`), so no program ever drops you into vi.
# Distro packages are years old (Debian/Ubuntu ship 0.4), so it is built from a pinned commit.
#   Linux/WSL: X11 build when the X11 headers are present (apt-packages.txt lists them):
#              `qe` opens an X window if $DISPLAY is set (WSLg sets it; XWayland on a Wayland desktop —
#              QEmacs has no native Wayland display), `qe -nw` stays in the terminal.
#              Also a launcher entry (qemacs.desktop) for the X window.
# Also links `qemacs-nw` (dotfiles/bin) into ~/.local/bin.
# Options: everything configure can detect, plus XShm, which it misses (it tests for "Xshm.h";
# the header is XShm.h).  Left out: FFmpeg (needs an FFmpeg source tree with a long-gone API) and
# Xrender/Xft (--enable-xrender only links libXrender; no code is behind it).
#   macOS:     terminal build (no X11 headers without XQuartz).
# Re-running is a no-op until QEMACS_REV or the configure options change.  Uninstall: make uninstall prefix=~/.local.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

QEMACS_REPO="https://github.com/qemacs/qemacs.git"
QEMACS_REV="2107926a07ff8553e7633bcee306779d62c496a5"   # 6.5.2, 2026-10-09
PREFIX="$HOME/.local"
STAMP="$PREFIX/share/qe/.build-rev"

CONFIGURE_OPTS=()
[[ $OS == Linux && -f /usr/include/X11/extensions/XShm.h ]] && CONFIGURE_OPTS+=(--enable-xshm)
WANT_STAMP="$QEMACS_REV${CONFIGURE_OPTS[*]:+ ${CONFIGURE_OPTS[*]}}"

_build_qemacs() {
    if [[ -x "$PREFIX/bin/qemacs" && "$(cat "$STAMP" 2>/dev/null)" == "$WANT_STAMP" ]]; then
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
    # No -j: with X11 the qe and xqe sub-makes both regenerate fbffonts.c, and in parallel one
    # compiles it while the other is still writing it ("expected expression").  Serial takes ~25 s.
    git clone -q "$QEMACS_REPO" "$src" \
        && git -C "$src" checkout -q "$QEMACS_REV" \
        && (cd "$src" && ./configure --prefix="$PREFIX" "${CONFIGURE_OPTS[@]}" >/dev/null && make >/dev/null 2>&1) \
        && [[ $("$src/qe" -V 2>&1) == *QEmacs* ]] \
        && make -C "$src" install >/dev/null \
        && echo "$WANT_STAMP" > "$STAMP"
    local rc=$?
    rm -rf "$src"
    if [[ $rc -eq 0 ]]; then
        info "Installed $PREFIX/bin/qe ($("$PREFIX/bin/qe" -V 2>&1 | sed -n 1p)); config file: ~/.qe/config."
    else
        err "QEmacs build failed — rerun by hand to see why: git clone $QEMACS_REPO; ./configure; make"
    fi
    return $rc
}

# Same link logic as 04-dotfiles' _deploy_link, for the one file this feature owns.
_link_wrapper() {
    local src="$REPO_DIR/dotfiles/bin/qemacs-nw" dest="$PREFIX/bin/qemacs-nw"
    mkdir -p "$PREFIX/bin"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        info "  $dest already linked."
        return 0
    fi
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        local bak="${dest}.bak-$(date +%F)"
        warn "  Backing up $dest → $bak"
        mv "$dest" "$bak"
    fi
    ln -sfn "$src" "$dest" && info "  $dest → $src"
}

# Launcher entry for the X11 window.  Without one, a desktop launcher has nothing but the bare
# command to go on.  Absolute Exec path: the desktop session's PATH may lack ~/.local/bin.
_desktop_entry() {
    [[ $OS == Linux ]] || return 0
    if ! ldd "$PREFIX/bin/qemacs" 2>/dev/null | grep -q libX11; then
        info "  Terminal-only build — no launcher entry."
        return 0
    fi
    local dest="$HOME/.local/share/applications/qemacs.desktop" want
    want="[Desktop Entry]
Type=Application
Name=QEmacs
GenericName=Text Editor
Comment=Quick Emacs: a small, fast editor (X11 window)
Exec=$PREFIX/bin/qemacs %F
Icon=accessories-text-editor
Terminal=false
Categories=Utility;TextEditor;"
    if [[ -f "$dest" && "$(cat "$dest")" == "$want" ]]; then
        info "  $dest already up to date."
        return 0
    fi
    mkdir -p "$(dirname "$dest")" && printf '%s\n' "$want" > "$dest" && info "  Wrote $dest"
    command_exists update-desktop-database && update-desktop-database -q "$(dirname "$dest")" 2>/dev/null
    return 0
}

run_step "QEmacs" _build_qemacs
run_step "qemacs-nw wrapper" _link_wrapper
run_step "Launcher entry" _desktop_entry
summary_report
