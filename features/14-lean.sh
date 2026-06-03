#!/usr/bin/env bash
# 14-lean — Install Lean 4 via elan and initialize.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

_install_elan() {
    if command_exists elan; then
        info "elan already installed."
        return 0
    fi
    
    if [[ "$OS" == "Darwin" ]]; then
        if ! brew list elan-init &>/dev/null; then
            info "Installing elan-init via Homebrew..."
            brew install elan-init
        fi
        
        # elan-init installs the 'elan' tool. We need to run it to set up the default toolchain.
        if ! command_exists elan; then
            info "Running elan-init..."
            # --default-toolchain stable: sets up stable Lean 4
            # -y: non-interactive
            elan-init -y --default-toolchain stable
        fi
    else
        info "Installing elan via official script..."
        curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain stable
    fi
}

_setup_path() {
    # elan usually adds itself to ~/.zshrc or ~/.profile.
    # We ensure it's available for the rest of the session if needed.
    if [[ -d "$HOME/.elan/bin" ]]; then
        export PATH="$HOME/.elan/bin:$PATH"
    fi
}

run_step "Install elan (Lean 4)" _install_elan
_setup_path

summary_report
