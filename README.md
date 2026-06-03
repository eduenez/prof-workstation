# prof-workstation

A modular, cross-platform workstation setup system for macOS (Homebrew),
Ubuntu/Debian Linux, and Windows Subsystem for Linux (WSL).

Designed for academics and professionals who work across multiple machines and
operating systems and need a reproducible, incrementally maintainable environment
covering the full stack: system packages, dotfiles, editors, languages, cloud
tools, fonts, and GUI applications.

---

## Platform support

| Platform | Package manager | Status |
|----------|----------------|--------|
| macOS (Apple Silicon / Intel) | Homebrew | Primary |
| Ubuntu / Debian Linux | apt | Supported |
| Windows WSL2 (Ubuntu) | apt | Supported |

> **Note:** This repository targets the *new* macOS environment (Homebrew-based).
> A companion repository, [elisp](https://github.com/eduenez/elisp), contains
> the Emacs configuration shared across all platforms.

---

## What this installs

| Feature module | Contents |
|---------------|----------|
| `prereqs` | Xcode Command Line Tools (macOS) / `build-essential` (Linux) |
| `pkgmgr` | Homebrew (macOS) / apt update (Linux) |
| `brew-bundle` | All Homebrew packages, casks, and fonts via `Brewfile` |
| `apt-pkgs` | Equivalent apt packages (Linux / WSL) |
| `dotfiles` | Shell config, Git, tmux, SSH skeleton, Karabiner |
| `emacs` | Emacs.app + `elisp` repo clone + elpaca bootstrap |
| `vscode` | VS Code + extension list |
| `python` | `uv` — Python versions, virtualenvs, and packages |
| `ruby` | `rbenv` + `bundler` |
| `r-pkgs` | R package bootstrap script |
| `cloud` | GitHub CLI (`gh`) and Google Cloud SDK (`gcloud`) auth |
| `ai-tools` | Ollama, Claude CLI, Gemini CLI |
| `macos-prefs` | Dock, Finder, keyboard settings via `defaults write` |
| `secrets` | Printed checklist: SSH keys, auth tokens, API keys |

**Homebrew Brewfile covers:**
core Unix tools · Git · TeX Live (via `mactex-no-gui`) · pandoc · gnuplot ·
asymptote · Emacs · SBCL · Node.js · Ruby · R · SageMath (isolated cask) ·
Nerd Fonts · iTerm2 · Chrome · Firefox · Brave · Signal · WhatsApp · Zoom ·
VLC · VS Code · and more.

---

## Prerequisites

- macOS: Command Line Tools (`xcode-select --install`) — the first feature
  installs these if absent.
- Linux / WSL: a working Ubuntu or Debian installation with `sudo` access.
- On any platform: this repository cloned or downloaded.

---

## Quick start

```bash
git clone https://github.com/eduenez/prof-workstation.git ~/repos/prof-workstation
cd ~/repos/prof-workstation
bash install.sh
```

The master script runs all feature modules in dependency order, reports progress
with colour-coded output, and prints a summary of any steps that failed at the end.
Failed steps do not abort the remaining independent steps.

---

## Usage

### Install everything

```bash
bash install.sh
```

### Install a single feature (on a new or existing machine)

```bash
bash install.sh brew-bundle  # re-run Homebrew installs (add new packages)
bash install.sh dotfiles     # re-deploy dotfiles
bash install.sh macos-prefs  # apply macOS system preferences
bash install.sh vscode       # install / sync VS Code extensions
```

Every feature module is **idempotent**: re-running it on a machine where the
feature is already installed is a fast no-op. This makes it safe to use both
for initial setup and for incremental updates to an existing environment.

### List available features

```bash
bash install.sh --list
```

---

## Repository layout

```
prof-workstation/
├── install.sh              # Master orchestrator
├── Brewfile                # All Homebrew packages, casks, and fonts
├── lib/
│   └── common.sh           # Shared helpers: run_step, logging, OS detection
├── features/
│   ├── 00-prereqs.sh
│   ├── 01-pkgmgr.sh
│   ├── 02-brew-bundle.sh   # macOS only
│   ├── 03-apt-pkgs.sh      # Linux / WSL only
│   ├── 04-dotfiles.sh
│   ├── 05-emacs.sh
│   ├── 06-vscode.sh
│   ├── 07-python.sh
│   ├── 08-ruby.sh
│   ├── 09-r-pkgs.sh
│   ├── 10-cloud.sh
│   ├── 11-ai-tools.sh
│   ├── 12-macos-prefs.sh   # macOS only
│   └── 13-secrets.sh
├── dotfiles/
│   ├── zshrc
│   ├── zprofile
│   ├── gitconfig.template  # Fill in NAME and EMAIL at install time
│   ├── tmux.conf
│   ├── ssh_config.template
│   └── karabiner/
├── lists/
│   ├── apt-packages.txt
│   ├── vscode-extensions.txt
│   ├── pip-requirements.txt
│   └── r-packages.R
└── README.md
```

---

## Python environment: `uv`

Python version and environment management is handled entirely by
[uv](https://github.com/astral-sh/uv) (installed via Homebrew / apt).

```bash
uv python install 3.12      # install a Python version
uv venv                     # create a virtualenv in the current directory
uv pip install -r lists/pip-requirements.txt
uv run script.py            # run a script in an isolated environment
```

`uv` is pip-compatible: `pip-requirements.txt` works unchanged.

---

## SageMath

SageMath is installed as a **standalone, isolated** macOS application
(`cask "sage"` in the Brewfile). It carries its own Python environment and
does not interact with the `uv`-managed Python stack. This prevents conflicts
between SageMath's heavy mathematical C-library dependencies and AI / ML
packages.

---

## Secrets and credentials

The `13-secrets.sh` module prints a checklist of steps that require manual
action — credentials are never stored in or injected by this repository:

1. Copy SSH private keys from the old machine
2. `gh auth login`
3. `gcloud auth login`
4. `M-x copilot-login` inside Emacs
5. Retrieve API keys (OpenAI, Anthropic, etc.) from LastPass and add to
   `~/.zshrc.local` as `export` statements (this file is not managed by
   this repo and will not be overwritten by re-running `dotfiles`)

---

## Customising for a different user

The `dotfiles/gitconfig.template` file contains `{{NAME}}` and `{{EMAIL}}`
placeholders that `04-dotfiles.sh` substitutes at install time.
SSH host entries are in `dotfiles/ssh_config.template` and are left as a
skeleton for manual completion.

All other configuration is shared between users with the same software stack.

---

## Relationship to the `elisp` repository

The [elisp](https://github.com/eduenez/elisp) repository contains the
full literate Emacs configuration (`emacs-config.org`) and its own
`setup.sh` for MacPorts-based machines. On Homebrew-based machines,
`features/05-emacs.sh` in this repository clones `elisp`, creates the
`~/.emacs.d` symlink, and installs the Copilot language server — the
Emacs Lisp configuration itself is shared and OS-aware internally.

---

## Acknowledgements

Shell helper patterns (`run_step`, `FAILED_STEPS`, colour-coded output)
adapted from `elisp/setup.sh`.
