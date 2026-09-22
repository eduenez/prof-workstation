#!/usr/bin/env bash
# 04-dotfiles — Oh My Zsh, zshrc, zprofile, gitconfig, tmux, SSH, Karabiner, MC.
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
        local bak="${dest}.bak-$(date +%F)"      # dated: never clobber an older .bak
        warn "  Backing up $dest → $bak"
        mv "$dest" "$bak"
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

_deploy_latexmkrc() {
    _deploy_link "$DOTFILES/latexmkrc" "$HOME/.latexmkrc"
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

MC_SKIN="modarin256-defbg-thin"
MC_SKIN_ROOT="modarin256root-defbg-thin"

# Idempotently pin `skin=$2` inside the mc ini at path $1, without touching
# any other setting — mc's ini is live, per-machine state that mc rewrites
# on every run (auto_save_setup=true), so it is never symlinked wholesale.
_mc_set_skin() {
    local mc_ini="$1" skin="$2"
    mkdir -p "$(dirname "$mc_ini")"
    if [[ ! -f "$mc_ini" ]]; then
        printf '[Midnight-Commander]\nskin=%s\n' "$skin" > "$mc_ini"
        info "  Created $mc_ini with skin=$skin"
    elif grep -q "^skin=$skin\$" "$mc_ini"; then
        info "  $mc_ini already set to skin=$skin"
    elif grep -q '^skin=' "$mc_ini"; then
        awk -v s="$skin" '{ if ($0 ~ /^skin=/) print "skin=" s; else print }' "$mc_ini" > "$mc_ini.tmp" && mv "$mc_ini.tmp" "$mc_ini"
        info "  Updated skin= in $mc_ini"
    elif grep -q '^\[Midnight-Commander\]$' "$mc_ini"; then
        awk -v s="$skin" '{ print; if ($0 == "[Midnight-Commander]" && !done) { print "skin=" s; done=1 } }' "$mc_ini" > "$mc_ini.tmp" && mv "$mc_ini.tmp" "$mc_ini"
        info "  Added skin=$skin to $mc_ini"
    else
        { printf '[Midnight-Commander]\nskin=%s\n\n' "$skin"; cat "$mc_ini"; } > "$mc_ini.tmp" && mv "$mc_ini.tmp" "$mc_ini"
        info "  Added skin=$skin to $mc_ini"
    fi
}

_deploy_mc() {
    local dest_dir="$HOME/.local/share/mc/skins"
    mkdir -p "$dest_dir"
    _deploy_link "$DOTFILES/mc/skins/$MC_SKIN.ini"      "$dest_dir/$MC_SKIN.ini"
    _deploy_link "$DOTFILES/mc/skins/$MC_SKIN_ROOT.ini" "$dest_dir/$MC_SKIN_ROOT.ini"

    _mc_set_skin "$HOME/.config/mc/ini" "$MC_SKIN"

    # `sudo mc` runs as root, with its own separate config under root's
    # HOME — this repo's install never runs as root, so that copy has to be
    # deployed by hand, once, with:
    #   sudo mkdir -p /var/root/.local/share/mc/skins /var/root/.config/mc
    #   sudo cp "$DOTFILES/mc/skins/$MC_SKIN_ROOT.ini" /var/root/.local/share/mc/skins/
    #   sudo sh -c "printf '[Midnight-Commander]\nskin=$MC_SKIN_ROOT\n' > /var/root/.config/mc/ini"
    # (use /root instead of /var/root on Linux.)
}

run_step "Oh My Zsh"          _install_oh_my_zsh
run_step "zshrc + zprofile"   _deploy_shell_config
run_step "gitconfig"          _deploy_gitconfig
run_step "tmux.conf"          _deploy_tmux
run_step "latexmkrc"          _deploy_latexmkrc
run_step "SSH config template" _deploy_ssh_config
run_step "Karabiner config"   _deploy_karabiner
run_step "MC skin"            _deploy_mc

summary_report
