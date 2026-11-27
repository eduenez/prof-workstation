#!/usr/bin/env bash
# 03-apt-pkgs — Install apt packages (Linux / WSL only).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

if [[ "$OS" != "Linux" ]]; then
    info "Linux/WSL only — skipping on $OS."
    exit 0
fi

PKGLIST="$REPO_DIR/lists/apt-packages.txt"

_add_gh_repo() {
    if apt-cache show gh &>/dev/null; then
        info "GitHub CLI apt repo already present."
        return 0
    fi
    info "Adding GitHub CLI apt repository..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq
}

_install_pkgs() { apt_install_list "$PKGLIST"; }

run_step "GitHub CLI apt repo" _add_gh_repo
run_step "apt packages"        _install_pkgs
summary_report
