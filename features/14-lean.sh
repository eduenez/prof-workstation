#!/usr/bin/env bash
# 14-lean — Install Lean 4 via elan and set the default stable toolchain.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

_install_elan() {
    if command_exists elan; then
        info "elan already installed."
        return 0
    fi
    case "$OS" in
        Darwin)
            if ! command_exists brew; then
                err "Homebrew not found — run 01-pkgmgr first."
                return 1
            fi
            # brew install elan-init installs the 'elan' binary (elan-init is the formula name).
            info "Installing elan via Homebrew (formula: elan-init)..."
            brew install elan-init
            ;;
        Linux)
            info "Installing elan via official script (includes stable toolchain)..."
            curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf \
                | sh -s -- -y --default-toolchain stable
            # Make lean/lake shims available in the current session.
            export PATH="$HOME/.elan/bin:$PATH"
            # The curl installer sets up the default toolchain; no extra step needed.
            return 0
            ;;
    esac
}

_setup_lean_toolchain() {
    if ! command_exists elan; then
        warn "elan not found — skipping toolchain setup."
        return 1
    fi
    if elan toolchain list 2>/dev/null | grep -q 'stable'; then
        info "Lean stable toolchain already installed."
        return 0
    fi
    info "Installing Lean stable toolchain (this downloads ~1 GB)..."
    elan toolchain install stable
    elan default stable
}

_setup_path() {
    # Add lean/lake shims to PATH for the current session.
    # Add ~/.elan/bin to dotfiles/zprofile for persistence if not already there.
    [[ -d "$HOME/.elan/bin" ]] && export PATH="$HOME/.elan/bin:$PATH"
}

_setup_path
run_step "Install elan"          _install_elan
run_step "Lean stable toolchain" _setup_lean_toolchain

summary_report
