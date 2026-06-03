#!/usr/bin/env bash
# 06-vscode — Install VS Code extensions from lists/vscode-extensions.txt.
# VS Code itself is installed by 02-brew-bundle (cask "visual-studio-code").
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

EXTLIST="$REPO_DIR/lists/vscode-extensions.txt"

_install_extensions() {
    if ! command_exists code; then
        warn "'code' CLI not found."
        warn "In VS Code: Cmd+Shift+P → 'Shell Command: Install code in PATH', then re-run."
        return 1
    fi
    if [[ ! -f "$EXTLIST" ]]; then
        err "Extension list not found: $EXTLIST"
        return 1
    fi

    local installed
    installed="$(code --list-extensions 2>/dev/null)"
    local failed=0

    while IFS= read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^[[:space:]]*# ]] && continue
        if echo "$installed" | grep -qi "^${ext}$"; then
            continue
        fi
        info "  Installing $ext..."
        code --install-extension "$ext" --force &>/dev/null \
            || { warn "  Failed: $ext"; ((failed++)) || true; }
    done < "$EXTLIST"

    [[ "$failed" -eq 0 ]]
}

run_step "VS Code extensions" _install_extensions
summary_report
