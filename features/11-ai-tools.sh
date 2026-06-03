#!/usr/bin/env bash
# 11-ai-tools — Ollama, Claude Code CLI, Gemini CLI.
# Ollama on macOS is installed by 02-brew-bundle (cask "ollama").
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

_install_ollama() {
    if command_exists ollama; then
        info "Ollama already installed."
        return 0
    fi
    case "$OS" in
        Darwin)
            if command_exists brew; then
                info "Installing Ollama via Homebrew..."
                brew install --cask ollama
            else
                warn "Brew not found — install Ollama manually from ollama.com"
                return 1
            fi
            ;;
        Linux)
            info "Installing Ollama via official installer..."
            curl -fsSL https://ollama.com/install.sh | sh
            ;;
    esac
}

_install_claude_code() {
    if command_exists claude; then
        info "Claude Code CLI already installed."
        return 0
    fi
    if ! command_exists npm; then
        warn "npm not found — skipping Claude Code CLI install."
        return 1
    fi
    info "Installing Claude Code CLI (@anthropic-ai/claude-code)..."
    npm install -g @anthropic-ai/claude-code
}

_install_gemini_cli() {
    if command_exists gemini; then
        info "Gemini CLI already installed."
        return 0
    fi
    if ! command_exists npm; then
        warn "npm not found — skipping Gemini CLI install."
        return 1
    fi
    info "Installing Gemini CLI (@google/gemini-cli)..."
    npm install -g @google/gemini-cli
}

run_step "Ollama"          _install_ollama
run_step "Claude Code CLI" _install_claude_code
run_step "Gemini CLI"      _install_gemini_cli
summary_report
