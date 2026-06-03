#!/usr/bin/env bash
# 02-brew-bundle — Install all Homebrew packages, casks, and fonts via Brewfile.
# macOS only.  mactex-no-gui is ~5 GB and takes time.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

if [[ "$OS" != "Darwin" ]]; then
    info "macOS only — skipping on $OS."
    exit 0
fi

_brew_bundle() {
    if ! command_exists brew; then
        err "Homebrew not found — run feature '01-pkgmgr' first."
        return 1
    fi
    info "Running brew bundle (this may take a while for large casks)..."
    brew bundle install --file="$REPO_DIR/Brewfile" --no-upgrade
}

run_step "brew bundle" _brew_bundle
summary_report
