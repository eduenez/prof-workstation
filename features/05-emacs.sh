#!/usr/bin/env bash
# 05-emacs — Clone ~/repos/elisp and create ~/.emacs.d symlink.
# Emacs.app itself is installed by 02-brew-bundle (cask "emacs").
# Does NOT call elisp/setup.sh — that script is MacPorts-specific.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ELISP_REPO="$HOME/repos/elisp"
ELISP_REMOTE="https://github.com/eduenez/elisp.git"

_clone_elisp() {
    if [[ -d "$ELISP_REPO/.git" ]]; then
        info "~/repos/elisp already present."
        return 0
    fi
    info "Cloning elisp config..."
    mkdir -p "$HOME/repos"
    git clone "$ELISP_REMOTE" "$ELISP_REPO"
}

_symlink_emacs_d() {
    local link="$HOME/.emacs.d"
    if [[ -L "$link" && "$(readlink "$link")" == "$ELISP_REPO" ]]; then
        info "~/.emacs.d already linked to $ELISP_REPO."
        return 0
    fi
    if [[ -e "$link" ]]; then
        warn "Backing up $link → ${link}.bak"
        mv "$link" "${link}.bak"
    fi
    ln -s "$ELISP_REPO" "$link"
    info "~/.emacs.d → $ELISP_REPO"
}

_copilot_ls() {
    local copilot_dir="$ELISP_REPO/var/copilot"

    # Fix root-owned npm cache (from an accidental sudo npm invocation).
    if [[ -d "$HOME/.npm" ]] && \
       find "$HOME/.npm" -maxdepth 4 -not -user "$(id -un)" -print -quit 2>/dev/null | grep -q .; then
        warn "Fixing npm cache ownership (root-owned files detected)..."
        sudo chown -R "$(id -un)" "$HOME/.npm"
    fi

    if [[ -x "$copilot_dir/bin/copilot-language-server" ]]; then
        info "Copilot language server already installed."
        return 0
    fi
    if ! command_exists npm; then
        warn "npm not found — skipping Copilot language server."
        return 1
    fi
    info "Installing @github/copilot-language-server..."
    mkdir -p "$copilot_dir"
    npm -g --prefix "$copilot_dir" install @github/copilot-language-server
}

run_step "Clone elisp repo"        _clone_elisp
run_step "~/.emacs.d symlink"      _symlink_emacs_d
run_step "Copilot language server" _copilot_ls

echo ""
echo "Post-install (run inside Emacs):"
echo "  1. Launch Emacs — Elpaca auto-installs all packages on first run."
echo "     AUCTeX build (make elpa) is slow; wait for Elpaca to fully finish."
echo "  2. M-x nerd-icons-install-fonts"
echo "  3. M-x copilot-login"
echo "  4. (Optional) M-x treesit-auto-install-all"
echo ""

summary_report
