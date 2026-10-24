#!/usr/bin/env bash
# 16-globalprotect — Tame Palo Alto GlobalProtect (UTSA VPN) on a personal Mac.
# The installer registers two KeepAlive LaunchAgents (pangps = service,
# pangpa = menu-bar app) that start at every login and cannot be quit from the
# UI. This feature symlinks gp-on / gp-off into ~/.local/bin and, if
# GlobalProtect is installed, disables both agents so it stays off until
# `gp-on`. The installer itself is NOT automated: it comes from the UTSA portal.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

[[ "$OS" != "Darwin" ]] && { info "macOS only — skipping."; exit 0; }

BIN_SRC="$REPO_DIR/dotfiles/bin"
BIN_DEST="$HOME/.local/bin"
AGENT_DIR="/Library/LaunchAgents"
LABELS=(com.paloaltonetworks.gp.pangps com.paloaltonetworks.gp.pangpa)

_link_scripts() {
    mkdir -p "$BIN_DEST"
    local s src dest rc=0
    for s in gp-on gp-off; do
        src="$BIN_SRC/$s"; dest="$BIN_DEST/$s"
        if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
            info "  $dest already linked."
            continue
        fi
        if [[ -e "$dest" || -L "$dest" ]]; then
            local bak="${dest}.bak-$(date +%F)"
            warn "  Backing up $dest → $bak"
            mv "$dest" "$bak" || { rc=1; continue; }
        fi
        ln -s "$src" "$dest" && info "  $dest → $src" || rc=1
    done
    return $rc
}

# Disable the agents so GlobalProtect no longer starts at login. Does not stop
# a running session (gp-off does that).
_disable_agents() {
    if [[ ! -e "$AGENT_DIR/${LABELS[0]}.plist" ]]; then
        info "GlobalProtect not installed — nothing to disable."
        return 0
    fi
    local disabled l rc=0
    disabled="$(launchctl print-disabled "gui/$(id -u)" 2>/dev/null)"
    for l in "${LABELS[@]}"; do
        if grep -q "\"$l\" => disabled" <<<"$disabled"; then
            info "  $l already disabled."
        else
            launchctl disable "gui/$(id -u)/$l" && info "  Disabled $l." || rc=1
        fi
    done
    return $rc
}

_remind_btm() {
    info "If GlobalProtect hangs on 'Connect' with 'BTM policy' in the launchd log,"
    info "enable Palo Alto Networks under System Settings → General → Login Items"
    info "& Extensions → Allow in the Background (see AGENTS.md, 2026-10-23)."
}

run_step "gp-on / gp-off in ~/.local/bin" _link_scripts
run_step "Disable GlobalProtect login agents" _disable_agents
_remind_btm
summary_report
