#!/usr/bin/env bash
# 17-repos — Keep every local clone current: the `repos` tool and its hourly fetch LaunchAgent.
# `repos` (fetch all clones, fast-forward the ones that can be, report the rest) lives in the private repository
# eduenez/site-tools, under repos/. This feature clones it to ~/repos/site-tools, symlinks `repos` into ~/.local/bin, and installs
# the LaunchAgent com.eduenez.repos.fetch (hourly `repos fetch --no-ssh`: fetch only, never fast-forwards unattended).
# The plist is kept in site-tools next to the tool and is copied here verbatim ($HOME is expanded by /bin/sh inside it), so
# re-running after `git pull` in site-tools refreshes the installed agent. Independent of Homebrew, so it also works on the MacPorts
# machines. macOS only (launchd).
#   REPOS_NO_AGENT=1 bash install.sh repos     link the tool but do not install the agent
#   remove the agent:  launchctl bootout gui/$(id -u)/com.eduenez.repos.fetch && rm ~/Library/LaunchAgents/com.eduenez.repos.fetch.plist
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

[[ "$OS" != "Darwin" ]] && { info "macOS only (launchd) — skipping."; exit 0; }

TOOLS_REPO="$HOME/repos/site-tools"
TOOLS_REMOTE="https://github.com/eduenez/site-tools.git"
BIN_DEST="$HOME/.local/bin"
LABEL="com.eduenez.repos.fetch"
PLIST_SRC="$TOOLS_REPO/repos/$LABEL.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
UNAVAILABLE=false

_clone_tools() {
    if [[ -d "$TOOLS_REPO/.git" ]]; then
        info "~/repos/site-tools already present."
        return 0
    fi
    info "Cloning site-tools..."
    mkdir -p "$HOME/repos"
    if git clone "$TOOLS_REMOTE" "$TOOLS_REPO"; then
        return 0
    fi
    # A private repository: on a machine or account without access this is not a failure of the setup.
    UNAVAILABLE=true
    warn "Could not clone $TOOLS_REMOTE (private; needs 'gh auth login', see 10-cloud). Skipping the repos tool."
    return 0
}

_link_tool() {
    $UNAVAILABLE && return 0
    local src="$TOOLS_REPO/repos/repos.py" dest="$BIN_DEST/repos"
    [[ -f "$src" ]] || { err "$src not found (site-tools out of date? git pull)."; return 1; }
    mkdir -p "$BIN_DEST"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        info "  $dest already linked."
        return 0
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        local bak="${dest}.bak-$(date +%F)"
        warn "  Backing up $dest → $bak"
        mv "$dest" "$bak" || return 1
    fi
    ln -s "$src" "$dest" && info "  $dest → $src"
}

_loaded() { launchctl print "$DOMAIN/$LABEL" &>/dev/null; }

_install_agent() {
    $UNAVAILABLE && return 0
    if [[ "${REPOS_NO_AGENT:-}" == "1" ]]; then
        info "REPOS_NO_AGENT=1 — not installing the LaunchAgent."
        return 0
    fi
    [[ -f "$PLIST_SRC" ]] || { err "$PLIST_SRC not found (site-tools out of date? git pull)."; return 1; }
    plutil -lint "$PLIST_SRC" >/dev/null || { err "$PLIST_SRC is not a valid plist."; return 1; }
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
    if _loaded && cmp -s "$PLIST_SRC" "$PLIST_DEST"; then
        info "  $LABEL already installed and loaded."
        return 0
    fi
    if _loaded; then
        info "  Reloading $LABEL (plist changed)."
        launchctl bootout "$DOMAIN/$LABEL" || return 1
    fi
    cp "$PLIST_SRC" "$PLIST_DEST" || return 1
    launchctl bootstrap "$DOMAIN" "$PLIST_DEST" || return 1
    info "  Loaded $LABEL (hourly; log ~/Library/Logs/repos-fetch.log)."
}

run_step "Clone site-tools"                 _clone_tools
run_step "repos in ~/.local/bin"            _link_tool
run_step "Hourly fetch LaunchAgent"         _install_agent
summary_report
