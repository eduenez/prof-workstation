#!/usr/bin/env bash
# 04-dotfiles — Oh My Zsh, zshrc, zprofile, gitconfig, tmux, SSH, Karabiner.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

DOTFILES="$REPO_DIR/dotfiles"

# Symlink $src to $dest, backing up any existing non-link file.
_deploy_link() {
    local src="$1" dest="$2"
    if [[ -L "$dest" ]]; then
        if [[ "$(readlink "$dest")" == "$src" ]]; then
            info "  $dest already linked."
            return 0
        fi
        warn "  $dest is linked elsewhere — relinking."
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        warn "  Backing up $dest → ${dest}.bak"
        mv "$dest" "${dest}.bak"
    fi
    ln -s "$src" "$dest"
    info "  $dest → $src"
}

_install_oh_my_zsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        info "Oh My Zsh already installed."
        return 0
    fi
    info "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

_deploy_shell_config() {
    _deploy_link "$DOTFILES/zshrc"    "$HOME/.zshrc"
    _deploy_link "$DOTFILES/zprofile" "$HOME/.zprofile"
}

_deploy_gitconfig() {
    local dest="$HOME/.gitconfig"
    if [[ -f "$dest" ]]; then
        info "~/.gitconfig already exists — skipping."
        return 0
    fi
    local template="$DOTFILES/gitconfig.template"
    local git_name git_email
    git_name="${GIT_NAME:-$(git config --global user.name 2>/dev/null || echo "")}"
    git_email="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || echo "")}"
    if [[ -z "$git_name" ]]; then
        printf "Git user name: " >&2
        read -r git_name || true
    fi
    if [[ -z "$git_email" ]]; then
        printf "Git email: " >&2
        read -r git_email || true
    fi
    if [[ -z "$git_name" || -z "$git_email" ]]; then
        warn "Git name/email empty — skipping. Set GIT_NAME and GIT_EMAIL env vars to automate."
        return 1
    fi
    sed -e "s/{{NAME}}/$git_name/g" -e "s/{{EMAIL}}/$git_email/g" "$template" > "$dest"
    info "Deployed ~/.gitconfig (name=$git_name, email=$git_email)"
}

_deploy_tmux() {
    _deploy_link "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"
}

_deploy_ssh_config() {
    local dest="$HOME/.ssh/config"
    if [[ -f "$dest" ]]; then
        info "~/.ssh/config already exists — skipping."
        return 0
    fi
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    cp "$DOTFILES/ssh_config.template" "$dest"
    chmod 600 "$dest"
    info "Deployed ~/.ssh/config template — fill in host entries manually."
}

_deploy_karabiner() {
    [[ "$OS" != "Darwin" ]] && return 0
    local dest="$HOME/.config/karabiner/karabiner.json"
    if [[ -f "$dest" ]]; then
        info "~/.config/karabiner/karabiner.json already exists — skipping."
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$DOTFILES/karabiner/karabiner.json" "$dest"
    info "Deployed karabiner.json."
}

run_step "Oh My Zsh"          _install_oh_my_zsh
run_step "zshrc + zprofile"   _deploy_shell_config
run_step "gitconfig"          _deploy_gitconfig
run_step "tmux.conf"          _deploy_tmux
run_step "SSH config template" _deploy_ssh_config
run_step "Karabiner config"   _deploy_karabiner

summary_report
