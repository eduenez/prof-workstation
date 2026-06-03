#!/usr/bin/env bash
# 07-python — Install uv, bootstrap Python 3.12, install global dev tools.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

PYTHON_VERSION="3.12"

_install_uv() {
    if command_exists uv; then
        info "uv already installed ($(uv --version))."
        return 0
    fi
    case "$OS" in
        Darwin)
            if command_exists brew; then
                info "Installing uv via Homebrew..."
                brew install uv
            else
                info "Installing uv via official installer..."
                curl -LsSf https://astral.sh/uv/install.sh | sh
                export PATH="$HOME/.local/bin:$PATH"
            fi
            ;;
        Linux)
            info "Installing uv via official installer..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
            export PATH="$HOME/.local/bin:$PATH"
            ;;
    esac
}

_install_python() {
    if ! command_exists uv; then
        warn "uv not found — skipping Python install."
        return 1
    fi
    if uv python list 2>/dev/null | grep -q "cpython-${PYTHON_VERSION}"; then
        info "Python $PYTHON_VERSION already managed by uv."
        return 0
    fi
    info "Installing Python $PYTHON_VERSION..."
    uv python install "$PYTHON_VERSION"
}

_install_pyright() {
    if ! command_exists uv; then
        warn "uv not found — skipping pyright install."
        return 1
    fi
    if uv tool list 2>/dev/null | grep -q 'pyright'; then
        info "pyright already installed."
        return 0
    fi
    info "Installing pyright (Python LSP) via uv tool..."
    uv tool install pyright
}

run_step "uv"                    _install_uv
run_step "Python $PYTHON_VERSION" _install_python
run_step "pyright (Python LSP)"  _install_pyright
summary_report
