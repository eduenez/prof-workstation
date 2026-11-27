#!/usr/bin/env bash
# 20-linux-desktop — Desktop-session extras for Linux machines with their own desktop (not WSL,
# not macOS): the packages in lists/apt-packages-desktop.txt, and CopyQ started at login.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

if [[ "$OS" != "Linux" ]] || $IS_WSL; then
    info "Desktop Linux only — skipping."
    exit 0
fi

_install_pkgs() { apt_install_list "$REPO_DIR/lists/apt-packages-desktop.txt"; }

# XDG autostart (Plasma, GNOME, ... all read ~/.config/autostart): link CopyQ's own launcher
# entry there.  An existing entry is left alone: CopyQ writes a copy itself when autostart is
# turned on in its preferences (or `copyq config autostart true`, which needs CopyQ running),
# and Hidden=true in it is how a desktop's settings record "disabled by the user".
_copyq_autostart() {
    local name="com.github.hluk.copyq.desktop"
    local src="/usr/share/applications/$name" dest="$HOME/.config/autostart/$name"
    if [[ -e "$dest" || -L "$dest" ]]; then
        info "  $dest already exists — leaving it alone."
        return 0
    fi
    [[ -f "$src" ]] || { warn "  $src not found — is copyq installed?"; return 1; }
    mkdir -p "$(dirname "$dest")" && ln -s "$src" "$dest" && info "  $dest → $src"
}

run_step "Desktop apt packages" _install_pkgs
run_step "CopyQ at login"       _copyq_autostart
summary_report
