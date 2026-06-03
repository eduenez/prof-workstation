#!/usr/bin/env bash
# install.sh — Orchestrate feature module installation.
#
# Usage:
#   bash install.sh              # run all features in order
#   bash install.sh <feature>    # run one feature (name without NN- prefix)
#   bash install.sh --list       # list available features
#
# Every feature is idempotent: safe to re-run on an existing machine.
# Feature failures are recorded but do not abort subsequent features.

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$REPO_DIR/lib/common.sh"

# ── Feature utilities ──────────────────────────────────────────────────

# Strip NN- prefix and .sh suffix to get the short name.
feature_short_name() {
    local f="${1##*/}"   # basename
    f="${f#[0-9][0-9]-}"
    printf '%s' "${f%.sh}"
}

# Collect all feature scripts in sorted order.
FEATURE_SCRIPTS=()
for f in "$REPO_DIR"/features/[0-9][0-9]-*.sh; do
    [[ -f "$f" ]] && FEATURE_SCRIPTS+=("$f")
done

# ── Argument parsing ───────────────────────────────────────────────────
TARGET="${1:-}"

if [[ "$TARGET" == "--list" ]]; then
    echo "Available features:"
    for f in "${FEATURE_SCRIPTS[@]}"; do
        printf '  %s\n' "$(feature_short_name "$f")"
    done
    exit 0
fi

if [[ -n "$TARGET" ]]; then
    matched=""
    for f in "${FEATURE_SCRIPTS[@]}"; do
        if [[ "$(feature_short_name "$f")" == "$TARGET" ]]; then
            matched="$f"
            break
        fi
    done
    if [[ -z "$matched" ]]; then
        err "No feature named '$TARGET'."
        echo "Run 'bash install.sh --list' to see available features." >&2
        exit 1
    fi
fi

# ── Run ───────────────────────────────────────────────────────────────
info "Platform : $OS $ARCH (WSL=$IS_WSL)"
info "Repo     : $REPO_DIR"

FAILED_FEATURES=()

run_feature() {
    local script="$1"
    local name
    name="$(feature_short_name "$script")"
    section "$name"
    if bash "$script"; then
        ok "Feature: $name"
    else
        warn "Feature '$name' completed with failures."
        FAILED_FEATURES+=("$name")
    fi
}

if [[ -n "$TARGET" ]]; then
    run_feature "$matched"
else
    if [[ ${#FEATURE_SCRIPTS[@]} -eq 0 ]]; then
        warn "No feature scripts found in $REPO_DIR/features/ — nothing to do."
        exit 1
    fi
    for f in "${FEATURE_SCRIPTS[@]}"; do
        run_feature "$f"
    done
fi

# ── Summary ────────────────────────────────────────────────────────────
echo ""
if [[ ${#FAILED_FEATURES[@]} -gt 0 ]]; then
    warn "Features with failures:"
    for f in "${FAILED_FEATURES[@]}"; do
        warn "  • $f"
    done
    warn "Re-run 'bash install.sh <feature>' to retry individual features."
    echo ""
    exit 1
fi
info "All done."
echo ""
