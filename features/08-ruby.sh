#!/usr/bin/env bash
# 08-ruby — Install rbenv + ruby-build, latest stable Ruby, bundler gem.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

_install_rbenv() {
    if command_exists rbenv; then
        info "rbenv already installed."
        return 0
    fi
    case "$OS" in
        Darwin)
            info "Installing rbenv + ruby-build via Homebrew..."
            brew install rbenv ruby-build
            ;;
        Linux)
            info "Installing rbenv + ruby-build..."
            if apt-cache show rbenv &>/dev/null; then
                sudo apt-get install -y rbenv ruby-build
            else
                git clone https://github.com/rbenv/rbenv.git      "$HOME/.rbenv"
                git clone https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build"
                export PATH="$HOME/.rbenv/bin:$PATH"
            fi
            ;;
    esac
}

_install_ruby() {
    eval "$(rbenv init - --no-rehash bash)" 2>/dev/null || true
    local latest
    latest="$(rbenv install -l 2>/dev/null \
        | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+\s*$' \
        | tail -1 \
        | tr -d ' ')"
    if [[ -z "$latest" ]]; then
        warn "Could not determine latest stable Ruby — check ruby-build is up to date."
        return 1
    fi
    if rbenv versions --bare 2>/dev/null | grep -qF "$latest"; then
        info "Ruby $latest already installed via rbenv."
    else
        info "Installing Ruby $latest..."
        rbenv install "$latest"
        rbenv global "$latest"
    fi
}

_install_bundler() {
    eval "$(rbenv init - --no-rehash bash)" 2>/dev/null || true
    if gem list bundler 2>/dev/null | grep -q bundler; then
        info "bundler already installed."
        return 0
    fi
    gem install bundler
}

run_step "rbenv + ruby-build" _install_rbenv
run_step "Latest stable Ruby" _install_ruby
run_step "bundler gem"        _install_bundler
summary_report
