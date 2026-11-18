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

# git.autofetch off, in the local User settings and in the remote-server Machine settings (VS Code Remote-SSH sessions
# into this machine; Machine settings override the connecting client's User settings). Auto-fetch fetches every repo
# in the workspace at once, each fetch asking the ssh agent (Bitwarden) for a signature; Bitwarden answers one and
# leaves the rest hanging with no prompt, and those stuck requests then block other git work. Fetching is done on
# demand instead (site-tools `repos`). settings.json is JSONC, so the key is inserted as text, never re-serialized.
_disable_git_autofetch() {
    local f
    for f in "$HOME/Library/Application Support/Code/User/settings.json" \
             "$HOME/.config/Code/User/settings.json" \
             "$HOME/.vscode-server/data/Machine/settings.json"; do
        case "$f" in
            */.vscode-server/*) ;;                                 # create it: the server reads it when present
            *) [[ -d "$(dirname "$f")" ]] || continue ;;           # VS Code not installed in that layout
        esac
        if [[ -f "$f" ]] && grep -q '"git.autofetch"' "$f"; then
            info "  $f already sets git.autofetch (left as is)."
            continue
        fi
        mkdir -p "$(dirname "$f")"
        if [[ ! -s "$f" ]]; then
            printf '{\n    "git.autofetch": false\n}\n' > "$f"
        else
            local tmp; tmp="$(mktemp)"
            awk '!done && /\{/ { sub(/\{/, "{\n    \"git.autofetch\": false,"); done=1 } { print }' "$f" > "$tmp" \
                && cat "$tmp" > "$f" && rm -f "$tmp"
        fi
        info "  git.autofetch=false → $f"
    done
}

run_step "VS Code extensions" _install_extensions
run_step "VS Code git.autofetch off" _disable_git_autofetch
summary_report
