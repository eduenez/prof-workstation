#!/usr/bin/env bash
# 04-dotfiles — Oh My Zsh, zshrc, zprofile, gitconfig, tmux, Ghostty, latexmkrc, latexindent, Claude Code (keybindings + skills), SSH (+ Bitwarden agent on Linux; on WSL a bridge to the Windows agent), Karabiner, MC.
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

_deploy_ghostty() {
    # Ghostty reads ~/.config/ghostty/config.ghostty on macOS as well as Linux.
    mkdir -p "$HOME/.config/ghostty"
    _deploy_link "$DOTFILES/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"
}

_deploy_latexmkrc() {
    _deploy_link "$DOTFILES/latexmkrc" "$HOME/.latexmkrc"
}

# latexindent: keep one backup instead of an unbounded name.bakN series.
# ~/.indentconfig.yaml must hold an absolute path, so it is generated rather
# than symlinked; it points at the repo's dotfiles/latexindent.yaml.
_deploy_latexindent() {
    local dest="$HOME/.indentconfig.yaml"
    local want
    want="# Managed by prof-workstation; do not edit directly.
paths:
- $DOTFILES/latexindent.yaml"
    if [[ -f "$dest" && "$(cat "$dest")" == "$want" ]]; then
        info "  $dest already up to date."
        return 0
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        local bak="${dest}.bak-$(date +%F)"
        warn "  Backing up $dest → $bak"
        mv "$dest" "$bak"
    fi
    printf '%s\n' "$want" > "$dest"
    info "  Wrote $dest → $DOTFILES/latexindent.yaml"
}

# Claude Code: keybindings and personal skills. Each skill is linked as its own
# directory, never ~/.claude/skills wholesale: that directory also holds
# entries other tools manage (e.g. `synced/`), which must stay out of this repo.
# A new skill is picked up by re-running `bash install.sh dotfiles`.
_deploy_claude() {
    mkdir -p "$HOME/.claude/skills"
    _deploy_link "$DOTFILES/claude/keybindings.json" "$HOME/.claude/keybindings.json"
    local skill
    for skill in "$DOTFILES"/claude/skills/*/; do
        skill="${skill%/}"
        _deploy_link "$skill" "$HOME/.claude/skills/$(basename "$skill")"
    done
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

# sshd runs ~/.ssh/rc at login: it relinks ~/.ssh/agent.sock to the forwarded agent (see tmux.conf).
_deploy_ssh_rc() {
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    _deploy_link "$DOTFILES/ssh/rc" "$HOME/.ssh/rc"
}

# zprofile, ssh_config.template and elisp's emacs-config.org all name the
# macOS socket path ~/.bitwarden-ssh-agent.sock.  The Linux Bitwarden snap
# puts its socket under ~/snap/bitwarden/<rev>/ instead; link the macOS path
# to the `current` revision so every consumer works unchanged and survives
# snap refreshes.  The link dangles while Bitwarden is not running — fine,
# the socket itself only exists then too.
_deploy_bitwarden_sock() {
    [[ "$OS" != "Linux" ]] && return 0
    local snap_sock="$HOME/snap/bitwarden/current/.bitwarden-ssh-agent.sock"
    local dest="$HOME/.bitwarden-ssh-agent.sock"
    if [[ ! -d "$HOME/snap/bitwarden" ]]; then
        info "Bitwarden snap not installed — skipping agent socket link."
        return 0
    fi
    if [[ -L "$dest" && "$(readlink "$dest")" == "$snap_sock" ]]; then
        info "  $dest already linked."
        return 0
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        warn "  $dest exists and is not the snap link — leaving it alone."
        return 1
    fi
    ln -s "$snap_sock" "$dest"
    info "  $dest → $snap_sock"
}

# WSL: Bitwarden is the Windows app, whose agent listens on the named pipe \\.\pipe\openssh-ssh-agent, which Linux
# programs cannot open.  A systemd user service bridges it to ~/.bitwarden-ssh-agent.sock (the path zprofile, the ssh
# config template and emacs-config.org already use) with socat + npiperelay.exe.  Windows side, once:
#   winget install -e --id albertony.npiperelay
# The relay is started through a small wrapper so a path with spaces ("Program Files") survives socat's EXEC parsing.
_deploy_wsl_agent_bridge() {
    $IS_WSL || return 0
    command_exists socat || { warn "  socat not installed (feature apt-pkgs) — skipping the Bitwarden bridge."; return 1; }
    command_exists systemctl && systemctl --user show-environment &>/dev/null \
        || { warn "  no systemd user manager (set [boot] systemd=true in /etc/wsl.conf, then wsl --shutdown)."; return 1; }
    local relay c
    relay="$(command -v npiperelay.exe 2>/dev/null)"
    if [[ -z "$relay" ]]; then
        for c in /mnt/c/Users/*/AppData/Local/Microsoft/WinGet/Links/npiperelay.exe \
                 "/mnt/c/Program Files/WinGet/Links/npiperelay.exe"; do
            [[ -e "$c" ]] && { relay="$c"; break; }
        done
    fi
    [[ -n "$relay" ]] || { warn "  npiperelay.exe not found. On Windows: winget install -e --id albertony.npiperelay"; return 1; }
    local wrap="$HOME/.local/bin/bitwarden-agent-relay" unit="$HOME/.config/systemd/user/bitwarden-agent-bridge.service"
    mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
    printf '#!/bin/sh\n# written by prof-workstation 04-dotfiles: relay to the Windows Bitwarden SSH agent pipe\nexec "%s" -ei -s //./pipe/openssh-ssh-agent\n' \
        "$relay" >"$wrap" && chmod 755 "$wrap"
    cat >"$unit" <<'UNIT'
[Unit]
Description=Windows Bitwarden SSH agent at ~/.bitwarden-ssh-agent.sock (socat + npiperelay)

[Service]
ExecStartPre=/bin/rm -f %h/.bitwarden-ssh-agent.sock
ExecStart=/usr/bin/socat UNIX-LISTEN:%h/.bitwarden-ssh-agent.sock,fork,umask=077 EXEC:%h/.local/bin/bitwarden-agent-relay,nofork
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
UNIT
    systemctl --user daemon-reload && systemctl --user enable --now bitwarden-agent-bridge.service \
        && systemctl --user restart bitwarden-agent-bridge.service \
        && info "  Bitwarden bridge running: ~/.bitwarden-ssh-agent.sock -> Windows agent (relay $relay)"
}

# gcr-ssh-agent.socket and ssh-agent.socket each `systemctl --user
# set-environment SSH_AUTH_SOCK=...` when started (gcr last, so it wins),
# clobbering the Bitwarden socket for every unit started afterwards —
# including emacs.service.  Masking only gcr just hands the job to
# ssh-agent.socket, so mask both.
_mask_competing_ssh_agents() {
    [[ "$OS" != "Linux" ]] && return 0
    $IS_WSL && return 0
    command_exists systemctl || return 0
    local unit
    for unit in gcr-ssh-agent.socket ssh-agent.socket; do
        if [[ "$(systemctl --user is-enabled "$unit" 2>/dev/null)" == "masked" ]]; then
            info "  $unit already masked."
        elif systemctl --user cat "$unit" &>/dev/null; then
            systemctl --user mask --now "$unit" && info "  Masked $unit"
        fi
    done
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

# Idempotently pin `$2=$3` inside the mc ini at path $1, without touching
# any other setting — mc's ini is otherwise live, per-machine state that mc
# rewrites on every run, so it is never symlinked wholesale.
_mc_set_key() {
    local mc_ini="$1" key="$2" value="$3"
    mkdir -p "$(dirname "$mc_ini")"
    if [[ ! -f "$mc_ini" ]]; then
        printf '[Midnight-Commander]\n%s=%s\n' "$key" "$value" > "$mc_ini"
        info "  Created $mc_ini with $key=$value"
    elif grep -q "^$key=$value\$" "$mc_ini"; then
        info "  $mc_ini already set to $key=$value"
    elif grep -q "^$key=" "$mc_ini"; then
        awk -v k="$key" -v v="$value" '{ if ($0 ~ "^" k "=") print k "=" v; else print }' "$mc_ini" > "$mc_ini.tmp" && mv "$mc_ini.tmp" "$mc_ini"
        info "  Updated $key= in $mc_ini"
    elif grep -q '^\[Midnight-Commander\]$' "$mc_ini"; then
        awk -v k="$key" -v v="$value" '{ print; if ($0 == "[Midnight-Commander]" && !done) { print k "=" v; done=1 } }' "$mc_ini" > "$mc_ini.tmp" && mv "$mc_ini.tmp" "$mc_ini"
        info "  Added $key=$value to $mc_ini"
    else
        { printf '[Midnight-Commander]\n%s=%s\n\n' "$key" "$value"; cat "$mc_ini"; } > "$mc_ini.tmp" && mv "$mc_ini.tmp" "$mc_ini"
        info "  Added $key=$value to $mc_ini"
    fi
}

_deploy_mc() {
    local dest_dir="$HOME/.local/share/mc/skins"
    mkdir -p "$dest_dir"
    _deploy_link "$DOTFILES/mc/skins/$MC_SKIN.ini"      "$dest_dir/$MC_SKIN.ini"
    _deploy_link "$DOTFILES/mc/skins/$MC_SKIN_ROOT.ini" "$dest_dir/$MC_SKIN_ROOT.ini"

    local mc_ini="$HOME/.config/mc/ini"
    _mc_set_key "$mc_ini" skin "$MC_SKIN"
    # auto_save_setup persists mc's *entire* live session state (including
    # the active skin) back into this ini on every exit — so any in-session
    # skin change (even just previewing one from Options > Appearance)
    # permanently overwrites the line above. Pin it off so skin= actually
    # stays put; deliberate option changes still persist via Options >
    # Save Setup (F9) when you want them to.
    _mc_set_key "$mc_ini" auto_save_setup false

    # `sudo mc` runs as root, with its own separate config under root's
    # HOME — this repo's install never runs as root, so that copy has to be
    # deployed by hand, once, with:
    #   sudo mkdir -p /var/root/.local/share/mc/skins /var/root/.config/mc
    #   sudo cp "$DOTFILES/mc/skins/$MC_SKIN_ROOT.ini" /var/root/.local/share/mc/skins/
    #   sudo sh -c "printf '[Midnight-Commander]\nskin=$MC_SKIN_ROOT\nauto_save_setup=false\n' > /var/root/.config/mc/ini"
    # (use /root instead of /var/root on Linux.)
}

run_step "Oh My Zsh"          _install_oh_my_zsh
run_step "zshrc + zprofile"   _deploy_shell_config
run_step "gitconfig"          _deploy_gitconfig
run_step "tmux.conf"          _deploy_tmux
run_step "Ghostty config"     _deploy_ghostty
run_step "latexmkrc"          _deploy_latexmkrc
run_step "latexindent (single backup)" _deploy_latexindent
run_step "Claude Code keybindings + skills" _deploy_claude
run_step "SSH config template" _deploy_ssh_config
run_step "ssh rc (agent link)" _deploy_ssh_rc
run_step "Bitwarden agent socket link" _deploy_bitwarden_sock
run_step "Bitwarden agent bridge (WSL)" _deploy_wsl_agent_bridge
run_step "Mask competing SSH agents" _mask_competing_ssh_agents
run_step "Karabiner config"   _deploy_karabiner
run_step "MC skin"            _deploy_mc

summary_report
