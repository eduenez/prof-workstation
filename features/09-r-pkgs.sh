#!/usr/bin/env bash
# 09-r-pkgs — Bootstrap R packages from lists/r-packages.R.
# R itself is installed by 02-brew-bundle (brew "r").
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

_install_r_pkgs() {
    if ! command_exists Rscript; then
        warn "Rscript not found — install R first (brew install r)."
        return 1
    fi
    local script="$REPO_DIR/lists/r-packages.R"
    if [[ ! -f "$script" ]]; then
        err "R package list not found: $script"
        return 1
    fi
    info "Installing R packages (may take several minutes)..."
    Rscript "$script"
}

run_step "R packages" _install_r_pkgs
summary_report
