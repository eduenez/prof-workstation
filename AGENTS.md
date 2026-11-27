# AGENTS.md

Context, design decisions, coding conventions, and status for AI agents (and
humans re-reading this later) working on `prof-workstation`.

---

## What this is

A modular, idempotent workstation setup system for **Eduardo Dueñez**
(mathematics professor / AI researcher, `eduardo@gibran.ai`, org: Gibran),
covering every machine he works on; it automates configuring a new one from
scratch.

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
(Superseded: `04-dotfiles` ran on `mac-studio` on 2026-06-03.)

### 2026-09-13 — TRAMP guard, dotfiles adoption on macbook-gai (Claude Fable 5.1 / Claude Code)

- Root-caused an Emacs TRAMP hang to `mac-studio` (Oh My Zsh under
  `TERM=dumb`: update prompt `[Y/n] ` false-matches TRAMP's prompt regexp,
  async git prompt never settles). Added the early `TERM=dumb` guard to
  `dotfiles/zshrc` (bare `$ ` prompt, `return` before Oh My Zsh loads).
- Found `mac-studio`'s `~/.zshrc` to be a stale copy; merged its `fzf --zsh`
  line into the template (guarded, generic) and re-linked it.
- Migrated `macbook-gai` (MacPorts) to the symlinked `zshrc`/`zprofile`:
  machine-specific lines → new `~/.zshrc.local` / `~/.zprofile.local`;
  `dotfiles/zprofile` gained the `~/.zprofile.local` hook and an
  `~/.rbenv/bin` PATH line (git-installed rbenv). `_deploy_link` backups
  are now dated. Procedure documented in README for `macbook-utsa`.

### 2026-09-16 — `~/.latexmkrc` deployed, forcing PDF output (Claude Sonnet 5 / Claude Code)

- latexmk's own default (`pdf_mode = 0`) builds DVI unless `-pdf` is passed
  explicitly, which doesn't match a typed-from-muscle-memory `latexmk`.
  Added `dotfiles/latexmkrc` (`$pdf_mode = 1;`) and a `_deploy_latexmkrc`
  step in `features/04-dotfiles.sh`, symlinked to `~/.latexmkrc` the same
  way as `tmux.conf`.
- Applied on `mac-studio` by running `bash install.sh dotfiles`, which also
  deployed the (previously undeployed) `~/.ssh/config` template as a side
  effect — that feature runs every dotfile in one pass. Harmless (template
  only, no real host entries) but worth knowing if only one dotfile is
  meant to move: run the specific `_deploy_*` step, not the whole feature.
- Verified: `rm toolkit.{dvi,pdf,...}; latexmk toolkit.tex` (no flags, in
  `~/repos/teaching/ProblemSolving/ProblemSetsPSC/Fall2026`) now produces
  `toolkit.pdf` directly, no `.dvi` at any point.
- Follow-up: that deployed `ssh_config.template` predates the Bitwarden SSH
  agent migration and still assumed a local-key workflow (`IdentityFile
  ~/.ssh/id_ed25519`, `AddKeysToAgent`, `UseKeychain`). Checked with
  `ssh -v -T git@github.com` under both the old and a candidate new config:
  agent-offered keys are tried *before* file-based ones either way (an
  explicit `IdentityFile` does **not** pre-empt the agent — initial worry,
  disproved by testing), so it was not silently bypassing Bitwarden. It was
  still the wrong default going forward, though: it offered a stale local
  key as a fallback on every host, and gave no guarantee of using Bitwarden
  for a process that never inherited `SSH_AUTH_SOCK` from `~/.zprofile` —
  exactly the failure mode `elisp/MACOS.md`'s "Environment: SSH_AUTH_SOCK"
  section documents for the launchd-started Emacs daemon. Replaced those
  three lines with `IdentityAgent ~/.bitwarden-ssh-agent.sock`, which pins
  the agent at the ssh-client-config level regardless of caller environment.
  Re-verified with `ssh -v -T git@github.com`: authenticates via the
  Bitwarden-agent key (`GibranSSHkey`), local `id_ed25519` never attempted.
- Found `~/.ssh/config.bad` and `~/.ssh/config~` on `mac-studio` (dated
  2026-08-24) — remnants of an earlier attempt at this same file, same
  generic template plus one manually-added `Host msuk` entry. Left in
  place, untouched; not migrated into the template since host aliases are
  meant to be filled in manually per machine, but worth restoring by hand
  if `msuk` is still a host in use.

### 2026-09-28 — `LIBGS` for dvisvgm (Claude Opus 5.5 / Claude Code)

- On macOS, TeX Live's dvisvgm loads Ghostscript's library at run time (TikZ
  needs it) but doesn't search Homebrew's or MacPorts' lib directory, so
  `dvisvgm --version=yes` listed no Ghostscript on `mac-studio`. Added a guarded
  block to `dotfiles/zprofile` that sets `LIBGS` from `$HOMEBREW_PREFIX` or
  `/opt/local` when unset. Debian/Ubuntu's dvisvgm links libgs directly.
- Chose `zprofile` over a new `zshenv`. Only dvisvgm reads the variable, and in
  a shell it runs from login sessions. The Emacs daemon, started by launchd,
  gets it from `elisp`'s `emacs-config.org`. `mac-studio`'s `~/.zshenv` is an
  unmanaged, machine-specific file (Ollama), which a managed `zshenv` would
  have had to absorb.

### 2026-09-29 — documented Shift+Enter/iTerm2 keyboard-protocol gotcha (Claude Sonnet 5 / Claude Code)

- No code change. `dotfiles/tmux.conf`'s `extended-keys`/`terminal-features`
  lines were already correct (tmux-side forwarding of Shift+Enter etc.), but
  the client-side half lives in iTerm2's GUI and isn't scriptable, so it was
  undocumented and easy to forget on a fresh machine. Added a "Known issues
  and TODOs" entry with the diagnosis and the fix (iTerm2's "Report modifiers
  using CSI u," or trusting the Kitty-keyboard-protocol auto-negotiation
  tmux/iTerm2 already support).

### 2026-09-29 — patched detex for Recoll; elan PATH (Claude Opus 5.5 / Claude Code)

- After `texlive-full` was installed on ChatEDG (Ubuntu), `recollindex`
  (which indexes `/usr/share/doc/texlive-doc`) triggered repeated detex
  SIGSEGV coredumps. Root cause: OpenDetex 2.8.11 (TeX Live's `detex`)
  dereferences NULL on any `\includeonly` when run with `-n`, which Recoll's
  `rcltex` filter always passes; affected files index with no text. Also hits
  personal `.tex` files, so skipping TeX Live docs is not a fix.
- Fixed upstream in https://github.com/pkubowicz/opendetex/pull/91 (pending).
  Until it ships in TeX Live, new `features/15-detex.sh` builds OpenDetex at a
  pinned commit with `patches/opendetex-includeonly.patch` into
  `~/.local/bin` (on PATH via `zshrc`). It
  probes the detex on PATH first and skips when it doesn't crash, so it goes
  inert once a fixed TeX Live lands; then delete the feature and patch.
  Needs `flex` (added to `lists/apt-packages.txt`; Xcode CLT ships it).
  After installing, re-index affected files once with `recollindex -i`
  (stop `recollindex.service` first) — Recoll won't retry unchanged files.
- **2026-11-15 correction:** `recollhelperpath` does not reach `rcltex`. It is a
  shell filter that finds `detex` on `$PATH`, and the systemd user units' PATH
  lacks `~/.local/bin`, so `recollindex.service` kept running TeX Live's
  crashing `/usr/bin/detex` (Apport reports). Fixed on ChatEDG with drop-ins
  `~/.config/systemd/user/{recollindex,recoll-reconcile}.service.d/path.conf`
  that put `%h/.local/bin` first in PATH. Neither the drop-ins nor the
  Recoll units are managed by this repository. Re-indexing: files detex
  crashed on were stored as indexed with empty text, so neither
  `recollindex -k` (retries only recorded failures) nor `-i` alone (skips
  unchanged files) refreshes them; `recollindex -e` then `-i` on the list does.
- Same day, for Recoll's other helpers: `jupyter nbconvert` (`.ipynb`) via a uv
  tool in `07-python`, and `catdvi` (`.dvi`) in `lists/apt-packages.txt`.
  Retry those with `recollindex -k` (they were recorded as failures).
- Added `clang` to `lists/apt-packages.txt` (used to test the detex PR).
- New `dotfiles/ghostty/config.ghostty` (adopted from ChatEDG, deployed by
  `04-dotfiles`) with `shell-integration-features = ssh-env,ssh-terminfo`:
  `tmux attach` on `mac-studio` over SSH from Ghostty failed with "missing or
  unsuitable terminal: xterm-ghostty". Ghostty's `ssh` wrapper now installs
  its terminfo on the remote via `tic` (cached per host; `ghostty +ssh-cache`
  manages it), falling back to `TERM=xterm-256color`. Only applies to `ssh`
  typed in a Ghostty shell with shell integration (not TRAMP, mosh, or ssh
  from inside a local tmux, which already sets its own TERM).
- `dotfiles/zprofile` now adds `~/.elan/bin`; `14-lean.sh` passes
  `--no-modify-path` so elan's installer stops appending to the symlinked
  `~/.zprofile`.

### 2026-10-18 — tmux and Ghostty tuned for Emacs users (Claude Opus 5.5 / Claude Code)

- Chose tmux over zellij: zellij's default keys (Ctrl-p/n/s/o/t/h/q) and
  its "unlock-first" preset (Ctrl-g) collide with core Emacs keys, it is
  rarely preinstalled on ssh hosts, and it has no iTerm2 `-CC` equivalent.
- `dotfiles/tmux.conf`: prefix C-b → **C-z** (C-b is Emacs backward-char;
  C-z C-z sends a literal suspend), OSC 52 clipboard (`set-clipboard on`),
  true colour via `terminal-features` (replaces the `Tc` override),
  focus events, titles, Emacs `mode-keys`/`status-keys` pinned, splits and
  new windows in the current directory, minimal status bar with a PREFIX
  indicator, and a quick-reference block at the end. Validated on tmux
  3.7b (isolated `-L` server, no config errors).
- `dotfiles/ghostty/config.ghostty`: unbinds Ghostty defaults (mostly
  Linux, checked against `src/config/Config.zig` on main, v1.3.1) that
  swallow Emacs keys — `C--`/`C-0`/`C-=`/`C-+` (font size, moved to
  super), `C-RET`, `C-TAB`, `M-1…9`, `C-M-arrows`, `C-S-arrows`;
  `macos-option-as-alt = left`; light padding/cursor polish. **Not yet
  validated** — run `ghostty +validate-config` on a machine with Ghostty.
  Ghostty has tmux control-mode parser code but no user-facing `-CC`
  support yet, so `tmucs` stays iTerm2-only.
- `dotfiles/zshrc`: new `tm` alias (`tmux new -A -s main`).

### 2026-10-23 — GlobalProtect on a personal Mac: diagnosis, `gp-on`/`gp-off` (Claude Sonnet 5.5 / Claude Code)

- UTSA's GlobalProtect 6.2.5 (installed from the UTSA portal pkg, not
  automated here) hung on Connect on `mac-studio`. Root causes, in order
  found: (1) a reinstall left the old network extension
  `[terminated waiting to uninstall on reboot]` in `systemextensionsctl list`
  — only a reboot clears it (`systemextensionsctl reset` needs SIP off);
  (2) **BTM**: `PanGPS` never started because macOS Background Task
  Management had "Allow in the Background" off for Palo Alto Networks
  (remembered from the earlier install). `log show --predicate 'process ==
  "launchd" AND eventMessage CONTAINS "trusted spawn"'` gives "Service cannot
  be launched because of BTM policy" (0xa1); the app just logs
  `Failed to connect to server at port:4767` (error 61). Fix: System Settings
  → General → Login Items & Extensions → Allow in the Background; no reboot.
  (3) a manually launched app instance blocking launchd's copy: repeating
  "An old GlobalProtect instance exists" dialogs; kill the stray instance.
- Gotcha: **both** `pangps` (the service) and `pangpa` (the menu-bar app) are
  *user LaunchAgents* in `/Library/LaunchAgents`, `KeepAlive`, `RunAtLoad`
  — not system daemons — so use `gui/$(id -u)/…`, never `sudo … system/…`.
  That is why the app can't be quit and always returns at login.
- New `features/16-globalprotect.sh` + `dotfiles/bin/gp-{on,off}`: symlinks
  the scripts into `~/.local/bin`; if GlobalProtect is installed, runs
  `launchctl disable` on both agents (persists across reboots) so it stays
  off until `gp-on` (enable + bootstrap, service first). It does not stop a
  running session. Re-run `bash install.sh globalprotect` after upgrading
  GlobalProtect, since the installer re-loads the agents. Independent of
  Homebrew, so it also works on the MacPorts machines.
- **Caution for `macbook-utsa`** (a UTSA-owned machine): if IT manages
  GlobalProtect there, don't run this feature without checking first.

### 2026-10-25 — `repos`: fetch all clones, fast-forward where safe; `17-repos` (Claude Sonnet 5.5 / Claude Code)

- New tool `repos` in the private repository `eduenez/site-tools` (`repos/repos.py`, stdlib only,
  tests in `repos/tests/`): `repos` = parallel `git fetch --all --prune`, then
  `git merge --ff-only @{u}` on the current branch only where safe; `repos fetch`, `repos status`,
  `repos list`. Never rebases, resets, stashes, checks out or pushes; diverged, detached and
  merge-in-progress repositories are only reported. `monorepo` (employer repository) was fetch-only
  at first; since 2026-11-15 (site-tools `f6ac655`) it is excluded by default (never fetched, merged
  or cloned) and allowed per machine with `allow_monorepo = true` in `~/.config/repos/config.toml`:
  only on ChatEDG, `macbook-gai`, `dalekanium`; never on the UTSA machines (`macbook-utsa`,
  `mac-studio`), where it must not exist.
- New `features/17-repos.sh`: clones `site-tools` to `~/repos/site-tools` (a private repository:
  if the clone is impossible, e.g. another account, the feature warns and exits 0), symlinks
  `repos` into `~/.local/bin`, and installs the LaunchAgent `com.eduenez.repos.fetch` (hourly
  `repos fetch --no-ssh`; fetch only, so no file changes under an open editor buffer).
  The plist lives in `site-tools` and is copied verbatim; the feature reloads the agent when it
  differs, so `git pull` in `site-tools` then `bash install.sh repos` refreshes it. `REPOS_NO_AGENT=1`
  links the tool without the agent. Log: `~/Library/Logs/repos-fetch.log`.
- Gotchas: launchd's PATH is only `/usr/bin:/bin:/usr/sbin:/sbin`, so the plist sets
  `PATH` for Homebrew and MacPorts; and the ssh agent a launchd job reaches is Apple's, not the
  shell's (Bitwarden's), hence `--no-ssh` (repositories with an ssh remote would only fail or
  raise an approval prompt every hour). `launchd` expands nothing, so the plist goes through
  `/bin/sh -c` to expand `$HOME`. Testing the feature under a scratch `$HOME` loses the macOS
  keychain (no https credentials): point `url.<local path>.insteadOf` at a local clone instead.

### 2026-10-25 — `18-latex-tools`: bibtex-tidy at the pinned version (Claude Opus 5.5 / Claude Code)

- New `features/18-latex-tools.sh`: installs `bibtex-tidy` (npm, global) at the version pinned in
  `~/repos/math-bibliography/.bibtex-tidy-version` (fallback `FALLBACK_TIDY_VERSION` in the script
  when that clone is absent; keep the two equal). `LaTeX-shared-files/_scripts/vendor.py` (`sync-all`)
  and math-bibliography's pre-commit hook call it, and `vendor.py` now refuses to run with any other
  version, since another version may reformat entries. Idempotent: a matching version is left alone,
  a different one is replaced. Needs npm (Brewfile: `node`).
- Why: `bibtex-tidy` had never been installed on `eduardoacstudio`, and `sync-all` failed on it.

### 2026-10-31 — Midnight Commander subshell hang with Oh My Zsh (Claude Sonnet 5.5 / Claude Code)

- Symptom (`macbook-gai`, MacPorts mc 4.8.33, zsh + OMZ `ys` theme): `mc` sat ~10 s with
  only one blinking character, then showed a literal `^[_` instead of the `$ ` prompt, and
  typing a command gave "the shell is already running a command" until ENTER.
- Root cause: OMZ's async git prompt (background job + `zle -F` handler) never settles
  under mc's subshell protocol (`precmd` hook doing `kill -STOP $$`; zle binding on `ESC _`
  to fetch the command line, which is the stray `^[_`). Bisected in isolated tmux servers:
  fast with no OMZ theme, with `mc -u`, or with a bash subshell; slow with any theme
  (even `robbyrussell`) and async on; fast again with `async-prompt no`.
- Fix: `dotfiles/zshrc` sets `zstyle ':omz:alpha:lib:git' async-prompt no` before OMZ loads,
  only when `$MC_SID` (exported by mc to its subshell) is set; normal shells keep async.
- Gotcha for testing: mc starts its zsh subshell through a temporary `ZDOTDIR` that still
  sources your rc, so `zsh -f` as the outer shell does **not** isolate the dotfiles; set
  `ZDOTDIR` to an empty dir to bypass them. Env-var `ZSH_THEME=...` tests are meaningless
  because the zshrc assigns it.

### 2026-10-31 — Ctrl-Tab / prefix Tab for tmux windows; Ghostty on macOS (Claude Sonnet 5.5 / Claude Code)

- Goal: switch tmux windows like GUI terminal tabs. `dotfiles/tmux.conf` now binds `prefix Tab` /
  `prefix S-Tab` (`-r`, repeatable) and, without the prefix, `C-Tab` / `C-BTab` (tmux's name for
  Ctrl-Shift-Tab) to `next-window` / `previous-window`. Tested against a real attached client in an
  isolated `-L` server by writing the escape sequences to a pty.
- Cost of the root binding: tmux now swallows Emacs's `C-<tab>`. Checked in Emacs 30.2 with the
  daemon's packages: unbound globally and in Org (its cycle-archived is `C-c C-<tab>`); used only by
  Magit/Forge `magit-section-cycle` (TAB, S-TAB, M-TAB still work), a minibuffer file-cache command,
  and `tab-bar-mode` (off). Accepted. Escape hatch if missed: pass the key through when
  `#{pane_current_command}` is emacs/emacsclient.
- **`macbook-gai` had no Ghostty config deployed**: `~/.config/ghostty/` did not exist, so none of
  `config.ghostty` (including the earlier "not yet validated" unbinds) was in effect. Linked it by
  hand; `ghostty +validate-config` passes (Ghostty 1.4.0). Check `ls -l ~/.config/ghostty` on any
  machine where a Ghostty setting seems ignored; `ghostty +list-keybinds` shows the effective set.
- **On macOS, `keybind = ctrl+tab=unbind` does not free the key.** Ghostty uses native macOS tabs, and
  AppKit adds Window → "Show Next/Previous Tab" (⌃⇥ / ⌃⇧⇥) itself (visible only with ≥2 tabs); an
  unbound key falls through to them. After remapping those, Ctrl-Tab became worse than before:
  it moved keyboard focus around the tab bar and the terminal got nothing. What works is an explicit
  binding that sends the xterm modified-key sequence, in `config.ghostty`:
  `ctrl+tab=csi:27;5;9~`, `ctrl+shift+tab=csi:27;6;9~`. tmux (`extended-keys on`) parses it, and
  forwards it to programs that request modified keys (Emacs does). `cat -v` shows `^[[27;5;9~`.
- Applied on `macbook-gai` only, not in the repo: `defaults write com.mitchellh.ghostty
  NSUserKeyEquivalents -dict-add "Show Next Tab" '^~@$n' "Show Previous Tab" '^~@$p'` (read only at app
  launch; quit Ghostty fully, since Cmd+Q may be cancelled by a confirm dialog and closing windows does
  not quit). It is probably redundant now that the explicit binding wins — **not tested without it**.
  Undo: `defaults delete com.mitchellh.ghostty NSUserKeyEquivalents`. Inspecting menus from a script
  (`osascript` + System Events, `AXMenuItemCmdChar`/`AXMenuItemCmdModifiers`) needs the Accessibility
  permission for the calling terminal.

### 2026-11-04 — Claude Code keybindings and personal skills (Claude Opus 5.5 / Claude Code)

- New `dotfiles/claude/`: `keybindings.json` (unbinds Ctrl+L, whose default
  `chat:clearInput` wipes the draft prompt irrecoverably; since 2026-11-18 also Ctrl+S, whose
  `chat:stash` keeps a single slot, so a second press with new text overwrites the earlier stash)
  and `skills/<name>/SKILL.md`
  for the teaching workflows: `course-problem-set`, `course-exam`, `psc-problem-set`,
  `publish-problem-set`. They drive `~/repos/course-data`, `teaching/problem-bank`,
  `teaching/ProblemSolving/ProblemSetsPSC`, `courses` and `psclub`; on a machine without
  those clones they are inert (they only tell Claude where to read).
- `04-dotfiles` `_deploy_claude` symlinks `keybindings.json` and **each skill directory
  individually** into `~/.claude/skills/` — never the directory itself, which also holds
  tool-managed entries (`synced/`). Edit skills in the repo (or through the symlink;
  same file); a *new* skill needs `bash install.sh dotfiles` to get its link.
  `~/.claude/settings.json` is deliberately not managed: per-machine and may hold tokens.

---

### 2026-11-01/02 — Windows target begins: dalekanium inventory and reinstall plan (Claude Opus 5.5 / Cowork)

- First Windows work in this repo. New `windows/` tree: `inventory.sh` (read-only snapshot of a
  Windows machine from Cygwin/WSL bash: software, registry settings, policies, services, drivers,
  WSL/Cygwin state), `prewipe-backup.sh` (robocopy of the profile + `wsl --export` + `wbadmin`
  system image to an external drive), `.gitattributes` (LF for `.sh`, CRLF for `.cmd`/`.bat`).
- `windows/dalekanium/`: `review.md` (as-is → to-be decisions per program and setting) and
  `PLAN.md` (handoff: status, machine facts, install media, phases, gotchas). Start there.
- Decisions: clean Win11 install (not in-place), local account via Rufus answer file, MSYS2
  replaces Cygwin, native MSYS2 Emacs as the Windows daily editor (WSL Emacs only for the
  `eat`-based Claude Code pane), Ubuntu 26.04 in WSL, Ditto as clipboard manager.
- Not yet written: `windows/setup/*` (policy/registry, winget + pacman manifests). Inventory
  output stays outside git (`M:\Eduardo\win-inventory`); it holds machine-specific details.

### 2026-11-03 — `macbook-gai` warm while asleep: diagnosis only (Claude Opus 5.5 / Claude Code)

- No code change. Symptom: the laptop was warm hours after closing the lid. The `pmset -g log`
  showed DarkWakes lasting 4–21 h, all on AC, with `powernap 1`. Background work during them:
  Photos `mediaanalysisd`, `fileproviderd` downloads (four cloud-drive accounts plus Syncthing),
  hourly `storagekitd` runs (>100 % CPU, 10–20 min, cause not confirmed) with the exFAT Crucial
  X9 plugged in and Spotlight indexing it, `coreaudiod` sleep-blockers from an unidentified app
  (one held 53 h), the hourly LaunchAgents and `com.apple.obc` maintenance wakes. Commands,
  fixes and the cost of turning off Power Nap: README → *Troubleshooting: Mac warm while asleep*.
- **Status: not fixed yet.** Power Nap is still on. Turning off Spotlight for the drive failed
  (see the README gotchas: sudo can't be used from `!`, and root `mdutil` via `osascript`
  couldn't resolve the removable volume). After the fixes are applied, check that DarkWake
  durations in `pmset -g log` drop under about 60 s. If they don't, look next at the external
  drive and the app holding audio open.
- Not automated in `12-macos-prefs` on purpose: Power Nap is a per-machine trade-off (desktops
  on AC may want it), and it needs sudo.

### 2026-11-04 — `aggressive-resize` removed from `tmux.conf` (Claude Opus 5.5 / Claude Code)

- `tmux -CC attach` in iTerm2 refused to run: "aggressive tmux resizing is turned on". The
  2026-10-18 tuning had added `setw -g aggressive-resize on`, which iTerm2's tmux integration
  does not support (it manages window sizes itself). Removed; tmux's default
  `window-size latest` (≥2.9) already covers the common case. A running server keeps the old
  value until `tmux set -gw aggressive-resize off` (or a restart); `source-file` does not unset it.
- Next, each tmux window opened as its own iTerm2 window. `OpenTmuxWindowsIn` was unset
  (default 0, native windows); `12-macos-prefs` now sets it to 1 (tabs in one new window). But
  it only applies to tmux windows iTerm2 has no saved layout for: iTerm2 stores the layout in
  the tmux session's `@affinities` option (hex; `sed 's/^a_//' | xxd -r -p` decodes it) and
  restores it on every attach. To reset it, detach, then `tmux set -u -t <session> @affinities`.
  Alternatively, drag the tabs together while attached; iTerm2 saves the new layout.
- Applied on `mac-studio` the same day. Lessons: `12-macos-prefs` had never run there, so
  `OpenTmuxWindowsIn` was unset; a repo change to a `defaults` setting does nothing until the
  feature (or the `defaults write` line) runs on each machine. Clear `@origins` (saved window
  positions) along with `@affinities`. `tmux.conf` now sets `aggressive-resize off` explicitly,
  so `tmux source-file ~/.tmux.conf` repairs servers on other machines still running with it on.

### 2026-11-09 — tmux: ssh agent follows the machine that attached last; `tm` (Claude Opus 5.5 / Claude Code)

- Symptom: `ssh msuk` from a tmux pane on `mac-studio` (iTerm2, on campus) hung, then failed. The
  same session was also attached from `macbook-gai` (asleep at home), whose forwarded agent had
  taken over: `~/.ssh/rc` relinked `~/.ssh/agent.sock` (every pane's `SSH_AUTH_SOCK`) on **every**
  ssh login, so the Bitwarden prompt went to the sleeping laptop.
- tmux has one environment per session, so with two clients from two machines there is no "which
  computer is this pane on". Policy chosen: one client at a time, and the agent follows the client
  that attached. The "most recently active client" alternative fails because tmux never updates
  `client_activity` for iTerm2's `-CC` client (it stays at the attach time).
- New `dotfiles/bin/tmux-agent-link PID`: reads the client's `SSH_AUTH_SOCK` (`ps -E` on macOS,
  `/proc/PID/environ` on Linux) and links `agent.sock` to it when it is a live forwarded socket,
  else to `~/.bitwarden-ssh-agent.sock`. `tmux.conf` runs it from a `client-attached` hook.
  `dotfiles/ssh/rc` no longer touches the link (it keeps the X11 part).
- New `dotfiles/bin/tm` (replaces the `tm`/`tmucs` aliases; `tmucs` is now `tm -c`): attaches to
  `main` with `new-session -A -D` (other clients detached), with `-CC` only in iTerm2
  (`TERM_PROGRAM=iTerm.app`, or `LC_TERMINAL=iTerm2`, which ssh forwards with `LC_*`), `-c`/`-p`
  to force either way. If only a session `0` exists it offers to rename it (default) or start
  `main` beside it. `04-dotfiles` links both scripts into `~/.local/bin`.
- Tested in an isolated server (`TMUX_TMPDIR` under `/tmp`: tmux's socket path is limited to
  ~104 bytes, which the scratchpad path exceeds; `TMUX_AGENT_LINK` redirects the link). Applied
  on `mac-studio` with `tmux source-file`. Other machines: `git pull && bash install.sh dotfiles`.

### 2026-11-04 — `qpdf` for course-data's PDF builds (Claude Opus 5.5 / Claude Code)

- `course-data`'s `make assignments` now builds each problem-set PDF aside and installs it with
  `bin/pdf-install`, which compares old and new via `qpdf` (decompressed, with xdvipdfmx's random
  font-subset tags, dates, `/ID` and xref offsets normalized) and keeps the tracked file when only
  build noise differs. Without it, mtime-triggered rebuilds (e.g. after a pull touching
  `course-template`'s preamble) showed up as modified PDFs in `git status`.
- Added `qpdf` to `Brewfile` and `lists/apt-packages.txt`. Without `qpdf` the script still works
  but always replaces the file, so the spurious diffs return. The MacPorts machines already have
  it (`port install qpdf` if one doesn't).

### 2026-11-15 — global gitignore link; gh as credential helper on Linux (Claude Opus 5.5 / Claude Code)

- `gitconfig.template` sets `core.excludesfile = ~/.gitignore_global`, which replaces git's default
  `~/.config/git/ignore`. On ChatEDG that file did not exist, so **no** global ignore rule applied, and
  `**/.claude/settings.local.json` (kept in `~/.config/git/ignore`) was silently no longer ignored.
  New `04-dotfiles` step `_deploy_gitignore_global`: if `~/.gitignore_global` is absent, link it to
  `~/.config/git/ignore` (created empty if absent); an existing file or link is left alone.
  Check the Macs: `git check-ignore -v .claude/settings.local.json` in any repository.
- `10-cloud`: when `gh` is logged in and the OS is not macOS (where `osxkeychain` does this), run
  `gh auth setup-git` unless gh already is the github.com credential helper, so private repositories
  cloned over https fetch without a prompt. Tested with `GIT_CONFIG_GLOBAL` on a scratch file.

### 2026-11-21 — MC: lynx-like motion, F2 menu modeled on Dired (Claude Sonnet 5.5 / Claude Code)

- `navigate_with_arrows` (the ini key behind Options > Panel options' "Lynx-like motion";
  lives in `[Panels]`, but `_mc_set_key` matches the key name anywhere in the file) pinned
  `true` in `04-dotfiles.sh`: Left goes to the parent directory, Right enters a
  directory/opens a file, matching Dired's quick directory stepping instead of arrow keys
  only moving the panel cursor.
- New `dotfiles/mc/menu` replaces the upstream F2 user menu (found at
  `$(brew --prefix mc)/etc/mc/menu` — system path is `mc.menu`, the per-user override read
  first is `~/.config/mc/menu`), linked there by `_deploy_mc`. Dropped the mid-1990s entries
  that don't apply here: mailing a bug report to root, Usenet newsbatch/uudecode/header
  stripping, `roff -man` display, and the ad hoc C-compile shortcut. Added entries modeled on
  Dired/Dirvish operations already in daily use: dired-dwim-target (`s`/`H` symlink/hardlink
  into the other panel), dired-diff (`c`: compare against the same-named file in the other
  panel), dired-do-compress-to (`a`: name the output archive, its extension picks the tool via
  `tar caf`/`zip`), plus `e` (emacsclient handoff — a directory opens Dired), `d`/`D` (disk
  usage), `g`/`l` (git status/log of this directory or file).
- Verified the ini keys land and the menu symlinks correctly
  (`grep -E '^skin=|^auto_save_setup=|^navigate_with_arrows=' ~/.config/mc/ini`); could not
  launch an interactive `mc` session in this environment to click through the new F2 entries,
  so check them by hand on next use.
- The same `bash install.sh dotfiles` run also re-applied `skin=`/`auto_save_setup=` — i.e.
  `~/.config/mc/ini` had drifted back to stock defaults again (mtime `Nov 10`) since they were
  last pinned. This is at least the third time (`04-dotfiles.sh`'s `_deploy_mc`/`_mc_set_key`
  comments cover the first two causes: an in-session skin preview getting autosaved, and the
  whole file being deleted/regenerated once). Still unexplained; flagged to the owner, not
  re-investigated this session.

### 2026-11-22 — MC ini resets: root cause and a permanent lock (Claude Sonnet 5.5 / Claude Code)

- Root cause, found and fixed same day: an `mc` process had been running for 26+ days in a
  persistent tmux pane (`main:1.1`), started Oct 26 — mid the original skin/auto_save_setup
  troubleshooting, apparently just before that fix landed — and never exited. `tmux
  capture-pane` (read-only) showed it still rendering the stock default skin and the old
  upstream F2 menu: it loaded its config once at startup and had been carrying that stale,
  pre-fix snapshot in memory ever since (`lsof` confirmed it doesn't hold the ini file open).
  mc's Options dialogs (Panel options, Appearance, ...) and Options > Save setup write the
  *whole* ini immediately on confirm, independent of `auto_save_setup` — so any accidental
  dialog confirm in that one 26-day-old pane, at any point, would reset the file to Oct 26's
  values. That explains a reset happening long after the file was last correctly written, with
  no process exit in between. Owner had it quit (killed cleanly, confirmed via `ps -p`) — and
  that very quit immediately re-triggered the reset one more time (its in-memory
  `auto_save_setup` was still `true`), caught and fixed in the same run.
- Permanent fix: `_deploy_mc` now `chmod 444`s `~/.config/mc/ini` after writing it, on both
  macOS and Linux — no `chflags`/`chattr` needed. Verified empirically (isolated test ini
  under a scratch `XDG_CONFIG_HOME`, scripted keystrokes via `tmux send-keys` to reach Options
  > Save setup) that mc writes the ini with a plain truncating `open()`, not a
  write-temp-then-rename, so a read-only file makes that write fail outright (mc just shows a
  "Cannot save file" message and keeps running) — this requires no special privilege on either
  OS since it's an ordinary permission bit, unlike Linux's `chattr +i` (needs
  `CAP_LINUX_IMMUTABLE`, i.e. root) or even macOS's own `chflags schg` (root-only; `uchg` would
  have worked too, owner-toggleable, but plain `chmod` already does the job and needs no
  OS-specific command at all). `_mc_set_key`'s own edits still land post-lock: it replaces the
  file via `mv` (rename), which only needs write access to the directory, not to the file being
  replaced. To change a setting via the UI again (Options > Save setup, or any Options dialog's
  OK) and have it stick, `chmod u+w ~/.config/mc/ini` first; the next
  `bash install.sh dotfiles` re-locks it.

### 2026-11-22 — Ghostty: Cmd-W sends M-w instead of closing the tab (Claude Sonnet 5.5 / Claude Code)

- Follow-up to the tmux-copy-mode-vs-Emacs-mouse troubleshooting above, same day: the owner's
  pure-keyboard-copy-mode workaround (`C-SPC` … `M-w`) failed because macOS intercepts Cmd-W as
  "close this tab" before Ghostty ever forwards the key, and GUI Emacs.app's own
  `mac-command-modifier = 'meta` habit (Cmd-W = M-w there) doesn't carry over to a terminal, where
  Cmd-W belongs to the OS, not Emacs. `macos-option-as-alt = left` already makes *Option*-w send a
  real M-w, but that's not the muscle memory the owner has.
- Added `keybind = super+w=esc:w` to `dotfiles/ghostty/config.ghostty`'s "Keys Emacs needs" section:
  Cmd-W now sends a literal `ESC w` (confirmed via `ghostty +list-actions --docs`: `esc:` "Send an
  `ESC` sequence", same shape as the existing `csi:27;5;9~` bindings) — exactly what Option-w
  already produces — so it reaches tmux copy-mode's own `M-w` (copy selection) and Emacs's `M-w`
  alike. Deliberate trade-off, accepted by the owner: Cmd-W no longer closes a tab (Ghostty's menu
  Close still does). Validated with `ghostty +validate-config --config-file=dotfiles/ghostty/config.ghostty`
  (exit 0) on `mac-studio`, where the Ghostty app bundle is present but isn't the daily driver — the
  owner's actual Ghostty is on the MacBook, so this needs `git pull && bash install.sh dotfiles`
  there, then `cmd+shift+,` to reload (no restart needed; documented at the top of the file).

### 2026-11-25 — first full `install.sh` run on ChatEDG (Ubuntu 26.04): four fixes (Claude Fable 5.2 / Claude Code)

- **tmux still on `C-b`, no `C-Tab`:** not a deployment bug. The links were right, but the tmux
  server had been running since Oct 31 and keeps the config it started with; reloading Ghostty's
  config does not touch tmux, and `prefix r` exists only once the new config is loaded.
  `_deploy_tmux` now runs `tmux source-file ~/.tmux.conf` when a server is running.
- **`03-apt-pkgs`:** the list reader skipped whole-line comments only, so
  `joe   # jmacs: …` was passed to apt as one package name. It now strips trailing comments.
- **`09-r-pkgs`:** Debian/Ubuntu's R puts the root-owned `/usr/local/lib/R/site-library` first and
  adds the user library only if its directory exists, so `install.packages()` failed with "lib is
  not writable". `r-packages.R` now creates and uses `R_LIBS_USER` in that case, and exits non-zero
  when a package fails (R itself only warns). Source builds also need headers, now in
  `lists/apt-packages.txt` (`libharfbuzz-dev`, `libfribidi-dev`, `libjpeg-dev`, `libgit2-dev`, …):
  without them `textshaping` and `ragg` fail, and with them `tidyverse`, `devtools`, `pkgdown`.
- **`19-qemacs`:** `make -j4` races when X11 headers are present (the `qe` and `xqe` sub-makes both
  regenerate `fbffonts.c`; one compiles it half-written). Now a serial `make` (~25 s). The feature
  only looks in `~/.local/bin`: ChatEDG also has a hand-built 6.4.1 in `/usr/local/bin`, now
  shadowed by the pinned 6.5.2.
- `sudo` needs a terminal, so an agent cannot run `01-pkgmgr` / `03-apt-pkgs` itself; ask the owner.

### 2026-11-25 — QEmacs: XShm, `qemacs-nw`, launcher entry (Claude Fable 5.2 / Claude Code)

- The Linux build already had the X11 window (X11 + Xv); it runs under XWayland on a Wayland
  desktop (tested on ChatEDG, KDE Plasma 6). QEmacs has no native Wayland display.
- `19-qemacs` now passes `--enable-xshm` when `XShm.h` exists: upstream's configure tests for
  `Xshm.h` (wrong case), so it never detected it. The stamp file records the options, so a change
  of options rebuilds. Not enabled: FFmpeg (wants an FFmpeg source tree with an old API) and
  `--enable-xrender` (it only links libXrender; the Xft code is behind `CONFIG_XFT`, which
  configure never sets).
- New `dotfiles/bin/qemacs-nw` (`qemacs -nw`), linked into `~/.local/bin` by the feature. It
  replaces a hand-made `/usr/local/bin/qemacs-nw` on ChatEDG that pointed at the removed 6.4.1.
- New step writes `~/.local/share/applications/qemacs.desktop` (Linux, X11 builds only;
  generated, since `Exec` needs an absolute path). The window sets no `WM_CLASS`.

### 2026-11-27 — `20-linux-desktop`: CopyQ at login (Claude Fable 5.2 / Claude Code)

- New `features/20-linux-desktop.sh`, for Linux machines with their own desktop session: it
  exits on macOS and on WSL (`$IS_WSL`; the desktop there is Windows, clipboard manager Ditto).
  Installs `lists/apt-packages-desktop.txt` (so far `copyq`) and links CopyQ's launcher entry
  into `~/.config/autostart`. An existing autostart entry is left alone, including one with
  `Hidden=true` (the user turned it off in the desktop's settings).
- Not `copyq config autostart true`: that needs a running CopyQ server. On ChatEDG it had been
  set that way by hand, so the entry there is CopyQ's own copy, not the link.
- `apt_install_list FILE` moved from `03-apt-pkgs` into `lib/common.sh`; both features use it.
- Plasma's Klipper still runs beside CopyQ; turning it off is a manual tray setting.

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

**Exception — the managed dotfiles are shared with MacPorts machines.** Since
2026-09-13 `macbook-gai` (MacPorts, no Homebrew) also symlinks `dotfiles/zshrc`
and `dotfiles/zprofile`; `macbook-utsa` will follow. Therefore every block in
those two files must be *guarded* to be a no-op when its tool is absent
(`[[ -f /opt/homebrew/bin/brew ]] && …`, `command -v fzf >/dev/null && …`).
MacPorts `PATH` and other MacPorts-only lines live in that machine's
`~/.zprofile.local` / `~/.zshrc.local` — still never in `dotfiles/`.

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
`$HOME`. Changes to the repo apply immediately on every machine (after `git pull`).

`gitconfig` is a **copy** (filled template). `karabiner.json` is also a
**copy** — Karabiner-Elements modifies it at runtime when settings are changed
via the UI, which would otherwise dirty the working tree.

**Trust, but `ls -l`.** On 2026-09-13 `mac-studio`'s `~/.zshrc` turned out to
be a plain *copy* (dated 1 Sep) carrying an unmerged local edit
(`eval "$(fzf --zsh)"`), so template changes were not reaching it; the edit
was folded into the template and the file re-linked. `_deploy_link` now backs
up to `~/.zshrc.bak-YYYY-MM-DD` (dated — a fixed `.bak` clobbered older
backups). Installers (juliaup, opam, conda, gcloud, Antigravity) append to
`~/.zshrc`, i.e. through the symlink into the repo: move such blocks to
`~/.zshrc.local` and `git checkout dotfiles/zshrc`. Migration procedure:
README → *Adopting the managed dotfiles on an existing machine*.

### `~/.zshrc.local` and `~/.zprofile.local` for machine-specific overrides
The managed `zshrc` sources `~/.zshrc.local` and the managed `zprofile`
sources `~/.zprofile.local`, each at its very end, if the file exists. Both
are intentionally not in this repo and must never be added. `~/.zshrc.local`
holds interactive things (aliases, `EDITOR`, API keys, installer blocks);
`~/.zprofile.local` holds login-time `PATH` (e.g. MacPorts, `pip --user`).

### Secrets by checklist only
No credential injection, no PM CLI. `13-secrets.sh` only prints a checklist.
Bitwarden (passwords, and SSH keys via its SSH agent) + macOS Keychain is
sufficient. (Formerly LastPass; `SetupNewComputer.md` is a historical
transcript and still says so.)

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
| `03-apt-pkgs` | ✓ | ✓ ChatEDG (Ubuntu 26.04) 2026-11-25 |
| `04-dotfiles` | ✓ | ✓ mac-studio 2026-06-03 · macbook-gai 2026-09-13 · ChatEDG 2026-11-25 |
| `05-emacs` | ✓ | — |
| `06-vscode` | ✓ | — |
| `07-python` | ✓ | — |
| `08-ruby` | ✓ | — |
| `09-r-pkgs` | ✓ | ✓ ChatEDG (Ubuntu 26.04) 2026-11-25 |
| `10-cloud` | ✓ | — |
| `11-ai-tools` | ✓ | — |
| `12-macos-prefs` | ✓ | — |
| `13-secrets` | ✓ | — |
| `14-lean` | ✓ | — |
| `15-detex` | ✓ | ChatEDG (Ubuntu) |
| `16-globalprotect` | ✓ | ✓ mac-studio 2026-10-23 |
| `17-repos` | ✓ (Linux: systemd user timer) | ✓ macbook-gai (MacPorts) 2026-10-25 · ChatEDG (Ubuntu) 2026-11-15 |
| `18-latex-tools` | ✓ | ✓ eduardoacstudio 2026-10-25 |
| `19-qemacs` | ✓ | builds on Ubuntu (DK's Linux VM) 2026-11-08 · ✓ ChatEDG 2026-11-25 |
| `20-linux-desktop` | ✓ | ✓ ChatEDG 2026-11-27 (packages present, autostart entry pre-existing; link path tested under a scratch `$HOME`) |

Update the "Tested" column as features are exercised on the Mac Studio.

---

## Known issues and TODOs

- **Global gitignore may be inactive on machines set up before 2026-11-15** (see that day's
  session note). Fixed on ChatEDG only. **Unchecked:** `mac-studio`, `macbook-gai`,
  `macbook-utsa`, `eduardoacstudio`, and WSL on `dalekanium`. The owner is not acting on this
  right away, so an agent working on one of those machines should run the check below and tell
  the owner before changing anything. Procedure:
  1. **Check** (read-only; the file need not exist):
     ```bash
     git config --global --get core.excludesfile        # the template sets ~/.gitignore_global
     ls -l ~/.gitignore_global ~/.config/git/ignore
     cd ~/repos/prof-workstation && git check-ignore -v .claude/settings.local.json
     ```
     If the last line prints a rule, this machine is fine. If it prints nothing, go on.
  2. **Fix, depending on what step 1 showed:**
     - `excludesfile` is unset: git already reads `~/.config/git/ignore`, so the rule is missing
       from that file. Add `**/.claude/settings.local.json` to it.
     - `~/.gitignore_global` is missing: `mkdir -p ~/.config/git && touch ~/.config/git/ignore &&
       ln -s ~/.config/git/ignore ~/.gitignore_global`. This is `04-dotfiles`'
       `_deploy_gitignore_global`, but run it by hand: `bash install.sh dotfiles` runs every
       dotfile step (see 2026-09-16).
     - Both are real files: only `~/.gitignore_global` is read, so rules in
       `~/.config/git/ignore` are lost. Show the owner both files, merge them into
       `~/.config/git/ignore`, back up `~/.gitignore_global` (dated `.bak`), then link it as above.
       Never delete either file without showing it first.
     - `~/.gitignore_global` exists and is read, but has no `.claude` rule: add the rule to it.
  3. **Look for leaks** while the rule was inactive (Claude Code's per-project settings can hold
     permission lists and paths):
     ```bash
     for r in ~/repos/*/; do git -C "$r" ls-files -- '.claude/settings.local.json' '*/.claude/settings.local.json' 2>/dev/null | sed "s|^|$r|"; done
     ```
     Report any hit to the owner; removing one from git (`git rm --cached`) is their call. None on
     ChatEDG (2026-11-15).
  4. **Record** the result here: move the machine from "Unchecked" to a line under this item.

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

- **Unverified Homebrew entries** (verify with `brew search` on the new machine):
  `brew "asitop"` — this tool is primarily distributed via PyPI; confirm it is in
  homebrew-core before relying on it. `cask "ipe"` — the IPE drawing editor may not
  be in homebrew/cask under that name. If either fails, `brew bundle` will report
  the error and continue past it.

- **Shift+Enter (and other shifted keys) need iTerm2 configured, not just tmux.**
  `dotfiles/tmux.conf` sets `extended-keys on` and
  `terminal-features 'xterm*:extkeys'`, the tmux-side half of forwarding
  modified keys (Shift+Enter, Shift+Tab, ...) to programs like `claude`
  instead of collapsing them to the bare key. That config has to be in effect
  on whichever host actually runs the tmux **server** — the remote box, if
  you `ssh` then `tmux attach` — not just present in this repo's local
  checkout. The other half is client-side, in iTerm2, and can't be scripted:
  - Try it with no iTerm2 changes first. Modern iTerm2 (≥3.5) and tmux
    (≥3.2, 3.5+ better) can auto-negotiate the Kitty keyboard protocol —
    tmux queries the outer terminal for support at attach — so a
    well-behaved inner program may already get correct modifier reporting
    for free.
  - If Shift+Enter still collapses to plain Enter, the fallback is iTerm2 →
    Settings → Profiles → [profile] → Keys → General → **"Report modifiers
    using CSI u."** iTerm2's own docs call this legacy and point to the
    Kitty protocol instead, but that's guidance for apps talking directly to
    a terminal. tmux sits in between here and explicitly still forwards this
    encoding (`extended-keys-format` supports `xterm`/`csi-u`/`kitty`) — it's
    a supported input path, not a hack that fights tmux's design, just the
    older of the two.

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

### 2026-11-05 — `latexindent` limited to one backup (Claude Sonnet 5.5 / Claude Code)

- `latexindent -w` writes `name.bak0`, `name.bak1`, … on every run (default
  `maxNumberOfBackUps` 1000), which littered `~/repos/research/*` with 32
  files. Not an Emacs setting.
- Added `dotfiles/latexindent.yaml` (`onlyOneBackUp: 1`, `backupExtension: .bak0`) and a
  `_deploy_latexindent` step in `features/04-dotfiles.sh`. It generates
  `~/.indentconfig.yaml` (absolute path to the repo file, so generated, not
  symlinked; idempotent, dated backup of any other file).
- Apply on other machines: `git pull && bash install.sh dotfiles` (this runs
  the whole dotfiles feature, see the 2026-09-16 note).
