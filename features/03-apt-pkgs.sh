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

_install_pkgs() {
    if [[ ! -f "$PKGLIST" ]]; then
        err "Package list not found: $PKGLIST"
        return 1
    fi
    local to_install=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
        dpkg -s "$pkg" &>/dev/null || to_install+=("$pkg")
    done < "$PKGLIST"

    if [[ ${#to_install[@]} -eq 0 ]]; then
        info "All apt packages already installed."
        return 0
    fi

    info "Installing ${#to_install[@]} package(s)..."
    local failed=0
    for pkg in "${to_install[@]}"; do
        info "  apt install $pkg..."
        sudo apt-get install -y "$pkg" || { warn "  Failed: $pkg"; ((failed++)) || true; }
    done
    [[ "$failed" -eq 0 ]]
}

run_step "GitHub CLI apt repo" _add_gh_repo
run_step "apt packages"        _install_pkgs
summary_report
