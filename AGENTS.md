# AGENTS.md

Context, design decisions, coding conventions, and status for AI agents (and
humans re-reading this later) working on `prof-workstation`.

---

## What this is

A modular, idempotent workstation setup system for **Eduardo Dueñez**
(mathematics professor / AI researcher, `eduardo@gibran.ai`, org: Gibran) and
a colleague with an identical software stack. Both users received new Mac
Studios; this repository automates configuring them from scratch.

**Old machine:** macOS Apple Silicon, MacPorts, ~1 635 installed ports.
**New machine:** macOS Apple Silicon (Mac Studio), Homebrew + uv from scratch.

The Emacs configuration lives in a companion repository,
[eduenez/elisp](https://github.com/eduenez/elisp), and is shared across all
machines. That repo has its own `setup.sh` which is **MacPorts-specific** and
must not be called from here.

---

## Session history

### 2026-06-02 — initial implementation (Claude Sonnet 4.6 / Claude Code)

Everything was designed and implemented in this session starting from a blank
repo with only `README.md` committed.

Files created in order:

1. `lib/common.sh` and `install.sh` — the orchestrator skeleton
2. All 14 `features/NN-*.sh` scripts
3. `Brewfile`
4. `lists/apt-packages.txt`, `lists/vscode-extensions.txt`,
   `lists/pip-requirements.txt`, `lists/r-packages.R`
5. `dotfiles/zshrc`, `dotfiles/zprofile`, `dotfiles/gitconfig.template`,
   `dotfiles/tmux.conf`, `dotfiles/ssh_config.template`,
   `dotfiles/karabiner/karabiner.json`
6. Minor README fixes + this file

VS Code extensions and the Karabiner config were extracted from the old
machine (MacPorts). The `dotfiles/` are adapted from `~/.zshrc`, `~/.zprofile`,
`~/.gitconfig`, and `~/.config/karabiner/karabiner.json` on the old machine.

**None of these scripts have been run on the target hardware yet.**

---

## Architecture

```
install.sh          orchestrator — discovers features/NN-*.sh, runs them
                    in order (or a single named feature)
lib/common.sh       sourced by install.sh and every feature; provides
                    run_step / FAILED_STEPS / summary_report, OS detection,
                    logging helpers, REPO_DIR
features/           one script per feature, numbered for dependency order
dotfiles/           managed config files, symlinked (or copied) by 04-dotfiles
lists/              plain-text package/extension/requirement lists
Brewfile            declarative Homebrew manifest (brew bundle)
```

`install.sh` runs each feature as a **subprocess** (`bash features/NN-name.sh`)
and records whether it succeeded. Feature-internal steps use `run_step`, which
collects failures without aborting the remaining steps. The two-level
reporting (feature-level in `install.sh`, step-level inside each feature)
gives a clean summary at the end.

---

## Design decisions

### Homebrew, not MacPorts
MacPorts is on the old machine only. The new machine uses Homebrew exclusively.
Do not add MacPorts references to this repo.

### uv, not conda / pyenv / pip-user
`uv` manages all Python versions, virtualenvs, and global tools. It is
pip-compatible (`pip-requirements.txt` works unchanged with `uv pip install`).
SageMath is the sole exception — it uses its own bundled Python via the
standalone cask and must never be mixed with uv environments.

### Feature-module architecture
Each `features/NN-name.sh` is independently runnable (`bash features/05-emacs.sh`)
and idempotent. The NN prefix sets dependency order in the full run. This allows
incremental updates on existing machines — not just fresh installs.

### `set -uo pipefail` without `-e`
`-e` would abort the entire script on any failure. Removing it and catching
failures per-step with `run_step` means a single broken package does not block
everything else. This pattern was validated in `elisp/setup.sh` and is
documented in `lib/common.sh`.

### Dotfiles via symlinks (except two)
`zshrc`, `zprofile`, and `tmux.conf` are **symlinked** from `dotfiles/` into
`$HOME`. Changes to the repo apply immediately on both machines.

`gitconfig` is a **copy** (filled template). `karabiner.json` is also a
**copy** — Karabiner-Elements modifies it at runtime when settings are changed
via the UI, which would otherwise dirty the working tree.

### `~/.zshrc.local` for machine-specific overrides
The managed `zshrc` sources `~/.zshrc.local` at the bottom if it exists. This
file is intentionally not in this repo and must never be added. It is where
API keys, machine-specific `PATH` additions, and per-machine aliases live.

### Secrets by checklist only
No credential injection, no PM CLI. `13-secrets.sh` only prints a checklist.
LastPass + macOS Keychain is sufficient for both users.

### `gitconfig.template` with `{{NAME}}` / `{{EMAIL}}`
The template is filled in at install time by `04-dotfiles.sh`, which reads from
`git config --global` if already set, or prompts interactively. The env vars
`GIT_NAME` and `GIT_EMAIL` override the prompt for automation.

### Linux / WSL as secondary target
All features are OS-aware. macOS-only features (`brew-bundle`, `macos-prefs`)
call `exit 0` cleanly on Linux. The Linux path (`03-apt-pkgs`) is a full
citizen but receives less testing.

---

## Feature status

| Feature | Implemented | Tested on target |
|---------|:-----------:|:----------------:|
| `00-prereqs` | ✓ | — |
| `01-pkgmgr` | ✓ | — |
| `02-brew-bundle` | ✓ | — |
| `03-apt-pkgs` | ✓ | — |
| `04-dotfiles` | ✓ | — |
| `05-emacs` | ✓ | — |
| `06-vscode` | ✓ | — |
| `07-python` | ✓ | — |
| `08-ruby` | ✓ | — |
| `09-r-pkgs` | ✓ | — |
| `10-cloud` | ✓ | — |
| `11-ai-tools` | ✓ | — |
| `12-macos-prefs` | ✓ | — |
| `13-secrets` | ✓ | — |
| `14-lean` | ✓ | — |

Update the "Tested" column as features are exercised on the Mac Studio.

---

## Known issues and TODOs

- **`bat` on Ubuntu <22.04** installs as `batcat`; a manual symlink or alias
  is needed. Consider adding a post-install note in `03-apt-pkgs.sh`.

- **`ruby-build` on Ubuntu** — the apt package may be too old for recent Ruby
  versions. `08-ruby.sh` has a fallback to clone from GitHub, but it is
  untested on the target hardware.

- **Python version pinned to 3.12** in `07-python.sh`. Update to 3.13 when
  the ML ecosystem broadly supports it.

- **`zprofile` calls `brew --prefix`** to locate the Google Cloud SDK path,
  adding ~50 ms to login-shell startup. Can hardcode `/opt/homebrew` on Apple
  Silicon once the target machine is confirmed to be ARM-only.

- **Karabiner device entries** in `dotfiles/karabiner/karabiner.json` contain
  the keyboard vendor/product IDs from the old machine (Apple Magic Keyboard
  1452/638, HP keyboard 1008/804). These may need to be updated to match the
  Mac Studio's peripherals; Karabiner-Elements allows this through its UI.

- **`tinytex` in `lists/r-packages.R`** may conflict with the full MacTeX
  installed via Brewfile. If there are issues, remove `"tinytex"` from the R
  package list and use the system TeX from MacTeX instead.

- **`06-vscode.sh` requires `code` in PATH.** After installing VS Code from the
  cask, the `code` CLI must be added manually via Cmd+Shift+P →
  "Shell Command: Install 'code' in PATH". The feature prints a clear warning
  if `code` is not found.

- **`09-r-pkgs.sh` has no retry logic.** If a CRAN package fails (network,
  compilation), the whole step is marked failed. Consider adding a retry loop
  or running `Rscript -e 'install.packages(...)'` per-package.

---

## Coding conventions

1. **Source line** — every feature starts with exactly:
   ```bash
   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
   ```
   This sets `REPO_DIR`, `OS`, `ARCH`, `IS_WSL`, and imports all helpers.

2. **Step functions** — name internal step functions with a `_` prefix
   (`_install_foo`, `_check_bar`). Call them via `run_step "Label" _fn`.

3. **End with `summary_report`** — every feature ends with this call.
   It prints any failed steps and exits non-zero if any failed. `install.sh`
   uses the exit code to decide whether to record the feature as failed.

4. **Idempotency** — check before acting. Use `command_exists`, `dpkg -s`,
   `brew list`, `-d "$dir"`, `-f "$file"`, etc. to skip steps already done.

5. **OS guard** — features that only apply to one OS should exit early:
   ```bash
   [[ "$OS" != "Darwin" ]] && { info "macOS only — skipping."; exit 0; }
   ```

6. **Package loops** — install packages one at a time in a `for` loop with
   per-item failure tracking. Never pass a space-separated list to a single
   install command where one failure aborts the rest.

7. **No hardcoded paths** — use `$REPO_DIR`, `$HOME`, `command_exists`, and
   `brew --prefix` rather than hardcoding `/opt/homebrew` or `/usr/local`.

8. **New features** — number them (next available NN), add to the feature
   status table in this file and the `What this installs` table in README.md.

---

## Relationship to `elisp`

| Concern | Repository |
|---------|-----------|
| Emacs Lisp configuration | `eduenez/elisp` (shared, OS-aware) |
| MacPorts-based system setup | `elisp/setup.sh` — old machine only |
| Homebrew-based system setup | **this repo** |
| Cloning `elisp` + `.emacs.d` symlink | `features/05-emacs.sh` |

`features/05-emacs.sh` clones `elisp` and creates `~/.emacs.d → ~/repos/elisp`.
It does **not** call `elisp/setup.sh`. Elpaca bootstraps itself on the first
Emacs launch using the config in `elisp/init.el`.
