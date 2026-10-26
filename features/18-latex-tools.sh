#!/usr/bin/env bash
# 18-latex-tools — Command-line tools of the LaTeX/bibliography workflow that TeX Live does not ship.
# bibtex-tidy (npm) formats math-bibliography/references.bib; LaTeX-shared-files' vendor.py (sync-all) and math-bibliography's
# pre-commit hook run it, and vendor.py refuses any version but the pinned one (another version may reformat entries).
# The pin lives in math-bibliography/.bibtex-tidy-version; this feature reads it when ~/repos/math-bibliography exists
# (cloned by 17-repos' users or by hand) and otherwise installs FALLBACK_TIDY_VERSION. Re-run after the pin changes.
# Needs npm (Brewfile: node). Works on the MacPorts machines too, given npm.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

PIN_FILE="$HOME/repos/math-bibliography/.bibtex-tidy-version"
FALLBACK_TIDY_VERSION="1.14.0"   # keep equal to math-bibliography/.bibtex-tidy-version

_install_bibtex_tidy() {
    local want have
    if [[ -f "$PIN_FILE" ]]; then
        want="$(tr -d '[:space:]' < "$PIN_FILE")"
    else
        want="$FALLBACK_TIDY_VERSION"
        info "$PIN_FILE not found — using bibtex-tidy $want."
    fi
    if command_exists bibtex-tidy; then
        have="$(bibtex-tidy --version 2>/dev/null | tr -d '[:space:]v')"
        if [[ "$have" == "$want" ]]; then
            info "bibtex-tidy $want already installed."
            return 0
        fi
        warn "bibtex-tidy $have installed; the bibliography is pinned to $want — reinstalling."
    fi
    if ! command_exists npm; then
        warn "npm not found — skipping bibtex-tidy (install Node.js, then re-run: bash install.sh latex-tools)."
        return 1
    fi
    info "Installing bibtex-tidy@$want (npm, global)..."
    npm install -g "bibtex-tidy@$want" || return 1
    have="$(bibtex-tidy --version 2>/dev/null | tr -d '[:space:]v')"
    [[ "$have" == "$want" ]] || { err "bibtex-tidy reports '$have' after installing $want."; return 1; }
}

run_step "bibtex-tidy (pinned)" _install_bibtex_tidy
summary_report
