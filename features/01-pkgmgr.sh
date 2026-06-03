#!/usr/bin/env bash
# 01-pkgmgr — Install Homebrew (macOS) or update apt (Linux).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

_install_homebrew() {
    if command_exists brew; then
        info "Homebrew already installed ($(brew --version | head -1))."
        brew update
        return 0
    fi
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Activate brew in this subprocess so subsequent steps in this feature can use it.
    # common.sh handles PATH injection for all other features.
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"       # Intel
    fi
}

_apt_update() {
    info "Running apt-get update..."
    sudo apt-get update -qq
}

case "$OS" in
    Darwin) run_step "Homebrew"   _install_homebrew ;;
    Linux)  run_step "apt update" _apt_update ;;
    *)      warn "Unsupported OS: $OS" ;;
esac

summary_report
