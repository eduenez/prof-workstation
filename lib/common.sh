#!/usr/bin/env bash
# lib/common.sh — Shared helpers sourced by install.sh and all feature modules.
# Do not execute directly.

set -uo pipefail   # -e intentionally omitted: failures are caught per-step

# Derive repo root from this file's location (lib/common.sh → parent = repo root).
: "${REPO_DIR:="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"

# ── Logging ────────────────────────────────────────────────────────────
info()    { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
warn()    { printf '\033[1;33m==> %s\033[0m\n' "$*"; }
err()     { printf '\033[1;31m==> %s\033[0m\n' "$*" >&2; }
ok()      { printf '\033[1;32m==>  %s\033[0m\n' "$*"; }
section() { printf '\n\033[1;35m──── %s ────\033[0m\n' "$*"; }

# ── Utilities ─────────────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }

# ── Platform detection ────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"
IS_WSL=false
if [[ "$OS" == "Linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
fi

# ── Step runner ───────────────────────────────────────────────────────
FAILED_STEPS=()

run_step() {
    local name="$1" fn="$2"
    echo ""
    info "── $name"
    if "$fn"; then
        ok "$name"
    else
        warn "$name FAILED — see output above; continuing with remaining steps"
        FAILED_STEPS+=("$name")
    fi
}

# Print a failure summary.  Returns 0 if clean, 1 if any steps failed.
# Feature scripts should call this as the last statement.
summary_report() {
    echo ""
    if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
        warn "The following steps had failures:"
        for s in "${FAILED_STEPS[@]}"; do
            warn "  • $s"
        done
        warn "Address the issues above and re-run to retry."
    fi
    [[ ${#FAILED_STEPS[@]} -eq 0 ]]
}
