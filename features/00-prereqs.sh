#!/usr/bin/env bash
# 00-prereqs — Xcode Command Line Tools (macOS) or build-essential (Linux).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

_xcode_clt() {
    if xcode-select -p &>/dev/null; then
        info "Xcode CLT already installed at $(xcode-select -p)."
        return 0
    fi
    info "Finding Command Line Tools package via softwareupdate..."
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    local label
    label="$(softwareupdate -l 2>&1 \
        | grep -B1 'Command Line Tools' \
        | awk -F'[*]' '/[*]/{print $2}' \
        | sed 's/^ //' \
        | grep -v '^$' \
        | tail -1)"
    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    if [[ -z "$label" ]]; then
        err "Could not find CLT in Software Update. Try: xcode-select --install"
        return 1
    fi
    info "Installing: $label"
    sudo softwareupdate -i "$label" --verbose
    sudo xcode-select --switch /Library/Developer/CommandLineTools
}

_build_essential() {
    if dpkg -s build-essential &>/dev/null && dpkg -s curl &>/dev/null; then
        info "build-essential and curl already installed."
        return 0
    fi
    info "Installing build-essential, curl, git..."
    sudo apt-get update -qq
    sudo apt-get install -y build-essential curl git
}

case "$OS" in
    Darwin) run_step "Xcode Command Line Tools" _xcode_clt ;;
    Linux)  run_step "build-essential + curl"   _build_essential ;;
    *)      warn "Unsupported OS: $OS" ;;
esac

summary_report
