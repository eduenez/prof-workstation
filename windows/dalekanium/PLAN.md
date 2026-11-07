# dalekanium — Windows 10 → clean Windows 11 reinstall

Handoff document: everything a later session (human or agent) needs to resume this work cold.
Companion files in this directory: `review.md` (the agreed as-is → to-be decisions, item by item).
Scripts: `../inventory.sh` (read-only capture), `../prewipe-backup.sh` (safety copies before the wipe).

## Status (2026-11-07)

- [x] Git over SSH on dalekanium works (Bitwarden agent via Windows OpenSSH; `url.insteadOf` rewrite). Plain `ssh` in Git Bash needs aliases to Windows OpenSSH (see gotchas)
- [x] Inventory captured: `M:\Eduardo\win-inventory\DALEKANIUM-20261101-*` (2343 is the complete one; 1853 also holds the **driver export**, `drivers\`, ~2 GB)
- [x] Review done and decisions recorded in `review.md`
- [x] `delfincito-pc` renamed `dalekanium` throughout `filetree-reorg`
- [x] Pre-wipe backup (2026-11-02) on the WD Elements: `\dalekanium-prewipe` (81 GB: profile copy, C:\ root folders, WSL tarballs for Leap 15.1 and 15.6) + system image `\WindowsImageBackup\DALEKANIUM`. The profile copy skipped 153 in-use files; the image covers them
- [x] Install media; one-page walk-through `walkthrough.pdf` (source `walkthrough.html`)
- [x] Phases 2–4: Windows 11 Pro installed 2026-11-02 (Chrome, VS Code, Claude desktop installed by hand)
- [x] Phase 5 applied (`windows/setup/configure.cmd`; Widgets via gpedit). Default apps turned out to be a manual step (2026-11-04, see gotchas). Terminal profile fragment still not picked up
- [~] Phase 6 (`windows/setup/packages.cmd`): apps, MSYS2, kanata (sign-in task), WSL Ubuntu-26.04, Bitdefender, TeX Live, NVIDIA driver done; **sync clients done 2026-11-05**: Google Drive (mirror of `M:\Eduardo\GoogleDrive`), OneDrive UTSA (`M:\OneDrive - University of Texas at San Antonio`, pinned), Dropbox (`M:\Eduardo\Dropbox`, offline); **Tresorit skipped** (`secreto` supersedes it). Emacs/elisp, Ghostscript pending
- [x] M: cleanup (side project below): snapshot on W:, ~140 GB deleted, games/ROMs moved to G: (2026-11-04/05)
- [~] Phase 7: **Syncthing paired and converged 2026-11-05** (Studio, hub, macbook-gai; `synchro` + `secreto` Send & Receive); `macbook-utsa`, `chatedg-probook` optional, pair when at hand. **Restic done 2026-11-05** (`windows/setup/restic/`): repository `W:\restic-dalekanium`, first snapshot 195 GiB / 132k files (168 GiB stored, 25 min), restore test 20/20 identical, nightly task `\dalekanium\restic-nightly` 04:30 ran OK. Still to confirm: a night with DK asleep (wake + back to sleep). Optional: start Syncthing at boot instead of sign-in
- [x] Emacs on Windows (MSYS2 UCRT64 build, elisp repo at `M:\Eduardo\repos\elisp` via the `~/.emacs.d` junction): works; Windows block in `emacs-config.org` (see gotchas). Slow on subprocess-heavy work (Magit) by Windows' nature → repository work moved to WSL
- [x] Windows Terminal: profiles fixed in its own `settings.json` (a fragment cannot override it): Git Bash default, cmd/Git Bash start in `M:\Eduardo`; PowerShell and Azure kept visible on request
- [x] **WSL Ubuntu-26.04 working environment (2026-11-07)**: `prof-workstation` cloned inside WSL (`~/repos`, Linux line endings), `install.sh apt-pkgs dotfiles`, zsh as login shell (`chsh`), SSH through the Windows Bitwarden agent (bridge below), `gh` logged in, `site-tools` `repos` tool + hourly fetch timer, all 37 GitHub repositories cloned into `~/repos`; Emacs with the same elisp config, daemon + `ec` launcher (elisp `setup.sh`), JetBrainsMono Nerd Font inside WSL
- [ ] Syncthing at Windows start (S4U task): `packages.cmd --apply syncthing` not yet run
- [x] Backup of WSL-only data: **decided not needed** (2026-11-07). WSL holds only configs and repository clones; the repos mirror/backup runs on mac-studio (read-only key). DK's role: Restic backup node, with the Studio and the hub as redundant copies
- [ ] **Offline copy on a portable SSD** (usually unplugged): `restic.sh offline-init X: --apply` (own repository `X:\restic-dalekanium-offline`, own password, chunker parameters copied from W:), then `restic.sh offline` whenever it is plugged in (`restic copy` from W:, same forget policy, prune, check 5%); `restic.sh status` reminds after 30 days. Written 2026-11-07, not yet run
- [ ] Afterwards: update `filetree-reorg` docs where they still describe dalekanium as "Windows 10, sleeps after active use" and assume `%USERPROFILE%\synchro` (it is `M:\Eduardo\synchro`) — Syncthing notes updated 2026-11-05

## Machine facts that drive the plan

- ASUS ROG STRIX B450-F GAMING, BIOS 2801 (2019), Ryzen 7 2700X (on the Win11 supported list), 32 GB, NVIDIA GPU, Intel LAN.
- Boots **legacy BIOS/CSM**, disks **MBR**, **no TPM** active → firmware changes needed (Phase 2).
- Disks: NVMe 477 GB = `C:` (wiped). SATA SSD 466 GB = `M:` (data, survives) **and holds the 1 GB "System Reserved" boot partition**. USB: WD Elements 13 TB (Restic vault, pre-wipe backup) and WD easystore 4 TB. **Drive letters on the new install (2026-11-03): `W:` = WD Elements ("W" for Western Digital: sorts last, easy to reassign after any future reinstall), `E:` = easystore, `F:` = DVD drive (never remapped);** the old install had Elements on F:.
- Windows 10 Pro **Retail**, activated → Win11 Pro activates on reinstall without a Microsoft account.
- `HOME=M:\Eduardo`; 12 known folders already point to `M:\Eduardo\…`; AppData stays on C:.

## Install media (download on dalekanium while still on Windows 10)

1. **Windows 11 ISO**, x64, current release (26H2 as of autumn 2026), from Microsoft's "Download Windows 11" page → section "Download Windows 11 Disk Image (ISO) for x64 devices", edition "Windows 11 (multi-edition ISO)", language English (United States).
2. **Rufus** (portable .exe, rufus.ie). Write the ISO to a USB stick of **≥ 8 GB, which gets erased**. Partition scheme **GPT**, target **UEFI (non CSM)**. In Rufus's "Windows User Experience" dialog tick: remove the online Microsoft-account requirement, create a local account named `Eduardo`, disable data-collection questions, **disable BitLocker automatic device encryption**. Leave the TPM/Secure Boot bypass **unticked** (this machine will meet both once Phase 2 is done). Also leave **unticked**: "Use 'Windows CA 2023' signed bootloaders" (this 2019 firmware almost certainly lacks the 2023 certificate, so Secure Boot would refuse the stick; Windows Update migrates the installed system to the 2023 chain itself later) and "Apply SkuSiPolicy.p7b" (an anti-rollback policy written into firmware variables that is hard to undo and can make older boot media unbootable; meant for high-security fleets).
3. Nothing else is required offline: the Intel LAN works with Windows' built-in driver, and the exported drivers on M: cover the rest.

## Phases

### 1. Before the wipe (Windows 10)
- Confirm OneDrive (UTSA), Tresorit, Google Drive, Dropbox all say "up to date".
- `bash prewipe-backup.sh copy`, then `bash prewipe-backup.sh image` (elevated Cygwin). Check `F:\dalekanium-prewipe\_prewipe.log` for FAIL lines.
- Put Total Commander's `wincmd.key` in Bitwarden (attachment) or `secreto`; it is git-ignored here.
- Commit and push `prof-workstation`.

### 2. Firmware (BIOS setup, `Del` at power-on)
- Advanced → AMD fTPM configuration → **Firmware TPM** (enable).
- Boot → CSM → **Disabled** (UEFI only).
- Boot → Secure Boot → OS Type **Windows UEFI mode**. Escape hatch: if the PC ever fails to boot after a Secure Boot certificate update, set Secure Boot → Disabled here; nothing is encrypted, so no data is at risk.
- Do **not** update the BIOS unless a concrete problem appears (e.g. fTPM-related stutter, fixed in later AMD firmware); if so, do it deliberately and supervised.

### 3. Install
- Power off. **Unplug the SATA cable of the M: SSD**, and both USB drives. Only the NVMe and the Rufus stick remain.
- Boot the stick (`F8` boot menu), choose the UEFI entry. Delete all partitions on the NVMe, install to the unallocated space (setup creates GPT + EFI partition there).
- First boot: local account `Eduardo` (from the Rufus answer file), privacy questions answered "no"/skipped.
- Power off, reconnect M:, F:, E:. Check drive letters in Disk Management (`M:`, `F:`, `E:`); fix if needed. The old System Reserved partition on the M: disk is now unused; leave it.

### 4. First boot essentials (manual, before any script)
- Activation check (Settings → System → Activation).
- Install Git for Windows and Bitwarden **machine-wide** (`winget install -e --id Git.Git --scope machine`, same for `Bitwarden.Bitwarden`; winget's default for these is per-user); enable the Bitwarden SSH agent; make sure the "OpenSSH Authentication Agent" service is **Disabled**.
- `setx HOME M:\Eduardo`; `git config --global core.sshCommand C:/Windows/System32/OpenSSH/ssh.exe` (or the `.gitconfig` on M: already carries it).
- `cd M:\Eduardo\repos\prof-workstation && git pull` — from here the setup scripts take over.

### 5. Windows configuration — `windows/setup/configure.sh` (+ `default-apps.xml`)
Run from Git Bash as administrator: `bash configure.sh` (dry run), then `bash configure.sh --apply`; sign out/in or restart.
Classic UI beyond what the registry can do: **StartAllBack** (paid, Win10/Win7-style taskbar with small icons, labels, top/side placement, classic Start and Explorer) — check its site lists support for the installed Windows build before buying; ExplorerPatcher is the free alternative but breaks more often after updates.
Policy and registry, in this order: Windows Update (download automatically, ask before install, no reboot while logged on, **drivers allowed, firmware blocked** (Firmware device-class install restriction; was "exclude drivers" until 2026-11-03), defer feature updates) → remove Copilot/widgets/ads/Spotlight/Start suggestions/telemetry where Pro allows → OneDrive personal account off (`DisablePersonalSync`, `KFMBlockOptIn` — **not** `DisableFileSyncNGSC`, which would also kill the UTSA account) → Scancode Map (Caps→Left Ctrl, Scroll Lock→Caps) → known folders → Explorer settings → classic context menu → keyboard layouts (US + US-International) → power (sleep, hibernate off, wake timers on, USB selective suspend off) → fonts from the saved user-fonts folder → restore drivers if any device is missing (`pnputil /add-driver M:\Eduardo\win-inventory\DALEKANIUM-20261101-1853\drivers\*.inf /subdirs /install`).

### 6. Software (scripted: `winget` manifest + MSYS2 `pacman` list), per `review.md`
Bitdefender Total Security (no VPN), Surfshark, browsers, sync apps (OneDrive UTSA, Tresorit, Google Drive, Dropbox — rename old folders first, see below), Cryptomator + WinFsp, Office/Teams, Git, gh, MSYS2 (Emacs, Unix tools, mintty, openssh), TeX Live, Ghostscript, Asymptote, Total Commander, Far Manager, Notepad++, VS Code, VLC, IrfanView, SumatraPDF, Adobe Reader, calibre, PDFtk, kdiff3, PowerToys, Ditto, WinCompose, All the Unicode, Gpg4win, Zoom, WhatsApp, Claude, NVIDIA driver only, Wacom driver, Brother HL-L2420DW driver. WSL: Ubuntu 26.04 LTS (stored on M:), `prof-workstation` Linux features inside it. Emacs: native MSYS2 build as daily editor, shared `elisp` repo; WSL Emacs only for the Claude Code pane.

Sync roots (done by hand 2026-11-03): personal sync folders live in `M:\Eduardo` (Dropbox, Google Drive, `private` = old Tresorit copy, a fresh Tresorit folder, and `synchro`, empty and reserved for Syncthing). The **UTSA work OneDrive is the one exception**: `M:\OneDrive - University of Texas at San Antonio`, outside the home directory, OneDrive location = `M:\`. The old local Dropbox folder is kept as the symlink `M:\Eduardo\Dropbox-old-local` (pre-prune content, incl. the old unencrypted `_private_sensitive`): Dropbox must sign in to a fresh folder, never this one.

Manual installs (not in winget or licence-bound): Bitdefender, Microsoft 365 (UTSA), NVIDIA driver only, TeX Live, **Ghostscript** (ghostscript.com), Tresorit (skipped for now: `secreto` supersedes it; `M:\Eduardo\private` is the frozen old copy), WhatsApp and All the Unicode (Store), StartAllBack (optional), UTSA VPN. winget ids are case-sensitive with `-e` (`SamHocevar.WinCompose`).

#### Sync clients: rules learned the hard way (Google Drive done 2026-11-05)
Goal for every client: the folder on M: is a **local clone**, every file **kept on disk** (never cloud-only), and the first sync **starts from the files already there** (seeded) instead of downloading everything again.
- **Clean the seed first.** A folder left by an older client holds the client's own stand-ins, which a new client would upload as real files. Google Drive's were `.gdoc`/`.gsheet`/… link files, `desktop.ini`, and **Windows shortcuts into the old virtual drive `G:\.shortcut-targets-by-id\…`, some disguised as `.pdf`/`.flac`** (218 bytes). They were moved aside (not deleted) to `M:\Eduardo\win-inventory\gdrive-seed-stubs` with lists; 18 of them are Drive shortcuts to items shared by others — the only things that stay cloud-only.
- **Google Drive**: before signing in, `HKLM\SOFTWARE\Google\DriveFS` `DefaultMountPoint`=`X:` (its virtual drive; `G:` is the FreeAgent) and `DefaultWebBrowser`=chrome.exe (sign-in never opens Edge). At sign-in **untick every "back up this computer" folder** — "Back up" uploads a one-way copy into Drive's *Computers* section (happened once; the partial copy was deleted online). Then Preferences → My Drive syncing options → **Mirror files** → `M:\Eduardo\GoogleDrive`: it reused the seed (a couple of minutes, no `(1)` duplicates, no nested `My Drive` folder). Docs/Sheets are always link files; that is inherent.
- **OneDrive (UTSA)**: at sign-in choose **"No, sign in to this app only"** and untick "Allow my organisation to manage my device" (otherwise the PC is registered with UTSA's tenant). Location `M:\` so the folder is `M:\OneDrive - University of Texas at San Antonio` (pre-seeded; check for orphaned cloud placeholders first). Files On-Demand cannot be switched off any more: right-click the root → **Always keep on this device**. `KFMBlockOptIn` (Phase 5) stops it from moving Desktop/Documents/Pictures.
- **Dropbox**: a fresh `M:\Eduardo\Dropbox` (never `Dropbox-old-local`); new files "available offline".

### 7. Backup node (per `filetree-reorg/design/syncthing_setup.md` and `restic_backup.md`, Phase 4)
Syncthing: pair with the mesh (Studio accepts the pending device), folders `synchro` and `secreto` at `M:\Eduardo\…`, versioning Simple/keep 3, `Thumbs.db` sweep task. Restic (done, `windows/setup/restic/restic.sh`: `setup`, `backup`, `nightly`, `status`, `restore-test`; password file `C:\ProgramData\dalekanium\restic\password` + Bitwarden; logs `C:\ProgramData\dalekanium\logs\restic-*`, one line per night in `restic-last.txt`, failures in the Application event log): independent repo on `W:` (WD Elements), own password, run by a Task Scheduler job that **wakes the PC**, holds it awake, waits for Syncthing to be idle, backs up, then sleeps it again. Bitdefender: exclude `synchro`, `secreto`, the Restic repo; allow Syncthing through its firewall. Restore test before calling it done. Back up `synchro`, `secreto`, `GoogleDrive`, `private` (frozen, in no other local backup) and the parts of `M:\Eduardo` that are in no sync service.

**Syncthing, as done 2026-11-05** (details in `filetree-reorg/design/syncthing_setup.md`): seeded from 7z archives; Bitdefender exceptions; DK added the Studio and hub by ID (no Introducer, no Auto Accept); the Studio was reached through an SSH tunnel to its GUI (`ssh -L 8385:127.0.0.1:8384 …`), the hub likewise (`ssh -L 8386:127.0.0.1:8384 admin@167.233.240.102`); folders accepted from the Studio's offer as **Receive Only**, reviewed, reverted, then switched to Send & Receive. `macbook-gai` paired directly (same LAN). DK's `synchro\.stignore` adds `(?d)Icon?` (macOS folder-icon files `Icon\r`; Windows cannot store the CR, 7-Zip had extracted them as `Icon_`) and one `(?d)/path` line per symlink (Syncthing does not sync symlinks on Windows).

## Side project: M: cleanup (2026-11-03 → 05, done)

M: (466 GB SSD) nearly filled once `synchro` + `secreto` were seeded; Google Drive (~100 GB) still had to fit.
Rules: nothing deleted until a verified copy exists; decisions in a reviewed manifest; executor dry-run by default.
Scripts in `cleanup/`; outputs (private file names) in `M:\Eduardo\win-inventory\` (outside git).

1. `cleanup/m-usage.sh` (report) and `cleanup/dupes-vs-synchro.sh` (files whose content is already in `synchro`).
2. `cleanup\m-snapshot.cmd` → `W:\M-Eduardo-snapshot-2026-11` (all of `M:\Eduardo` except synced folders; 303 GB,
   2026-11-04). Robocopy exits ≥8 on any failed file, so the `.snapshot-complete` marker was written by hand after the
   103 failures were reviewed (Dropbox cache, old Cygwin X dotfiles, 3 inventory copies of a settings file).
3. `cleanup/build-manifest.sh` → `cleanup/manifest.tsv` + `summary.txt`; overrides in `cleanup/overrides.tsv`.
4. `cleanup/apply-manifest.sh` (dry run; `--apply delete`; `--apply move-G`): ~140 GB deleted (installers, ISOs,
   old VMs, obsolete software, duplicates of `synchro`), ~87 GB of games/ROMs moved to `G:\M-Eduardo` with SHA-256
   verification. It never touches `win-inventory/cleanup` or `win-inventory/dupes-*`.
   Lessons: one `rm` per file is ~30 files/s in Git Bash (now batched through `xargs`, `-s 20000` max);
   files carried over from old Cygwin/system ACLs need `takeown` + `icacls /reset` before they can be deleted.

## Gotchas already found

### Found during the install (2026-11-02)

- **Computer name**: setup assigned `DESKTOP-379STP2`; rename to `DALEKANIUM` (configure.sh `name`), it matters for Syncthing labels and Restic host tags.
- **`winget` installs Chrome/VS Code per-user by default.** Always pass `--scope machine` (and `-e --id`); if a package has no machine installer, download the vendor's system-wide installer.
- **Edge grabs file types.** In Settings → Default apps, the "Microsoft Edge" entry's button *assigns* every type it can open to Edge; it does not open Edge's settings. Fix: Settings → Default apps → Google Chrome → **Set default** (one click), then any remaining Edge rows (`.pdf`, `.svg`, `.xml`, `.mht`, FTP, READ). **The `DefaultAssociationsConfiguration` policy does nothing here**: Windows applies it only on domain-joined PCs (found 2026-11-04, when GlobalProtect's "default browser" turned out to be Edge for everything); configure.sh `defaults` now removes it and only points the legacy `HKCR\http(s)\shell\open\command` at Chrome. Edge cannot be uninstalled on a US Windows install without breaking WebView2/updates; neutralise it instead (configure.sh `edge`). Optional: MSEdgeRedirect (open source) sends `microsoft-edge:` links from Start/Widgets/help to the default browser.
- **Passkey catch-22 in a new Chrome profile.** With no Bitwarden extension yet, a site asking for a passkey falls through to Windows' own dialog ("insert security key"). Order that avoids it: create the Chrome profile **without signing in**, install the Bitwarden extension, unlock Bitwarden, *then* sign in to Google/Claude. In Windows' dialog, "Cancel"/"Use another device" or the site's "Try another way" reach TOTP/password. Recent Windows 11 builds also let a password manager register as a system passkey provider (Settings → Accounts → Passkeys → Advanced options); enable Bitwarden there if it is offered.
- **kanata from winget** is the tray build `jtroo.kanata_gui`, a portable package: the program is `C:\Program Files\WinGet\Packages\jtroo.kanata_gui_Microsoft.Winget.Source_8wekyb3d8bbwe\kanata_windows_gui_winIOv2_x64.exe`, and the PATH command has that long name, not `kanata_gui`. Keypad Enter makes kanata beep with an error balloon (Windows reports it as plain Enter); it is excluded with `process-unmapped-keys (all-except kprt)` (the key name is `kprt`, not `kpenter`). A one-off "Unexpected keycode is pressed in kanata but not in Windows … NumLock" balloon after fast Num Lock taps is kanata resynchronising its key state; harmless.
- **kanata config comments need two semicolons** (`;;`); a single `;` is a parse error. Run the kanata exe from cmd to see its log and errors.
- **WSL Ubuntu-26.04** installed 2026-11-03 on `M:\WSL\Ubuntu-26.04`, Linux user `eduardo` (the old Leap distro used `eduenez`).
- **First `wsl --install` asks for a reboot**: it enables the Virtual Machine Platform feature and installs nothing yet; run the same command again after restarting.
- **Emacs on Windows reads `~/.emacs` before `~/.emacs.d/init.el`**: the old SuSE-era `M:\Eduardo\.emacs` must be renamed or it silently wins. `~/.emacs.d` is a junction to `M:\Eduardo\repos\elisp` (packages.sh `emacs`). Developer Mode is switched on so Elpaca/git can create symlinks without admin rights.
- **kanata sign-in task (2026-11-03)**: works when it starts the real build `WinGet\Packages\jtroo.kanata_gui_…\kanata_windows_gui_winIOv2_x64.exe` (not the `WinGet\Links` shortcut, not the `…_cmd_allowed_…` build) with that folder as working directory, **without admin rights** (`packages.cmd --apply kanata-user`). Launched elevated through the Links shortcut it aborted at once (0xC0000409); elevated + real exe is untested. Apparent Caps Lock "glitches" were windows running as administrator, which a non-admin kanata cannot see (accepted). `Shift+Win+V` → F13 (kanata), Ditto's activation key = F13 (2026-11-04, working; no stray Start menu); `Win+V` stays Windows' panel.
- **`schtasks /create` gives every task a 72-hour limit** after which Windows kills it; long-running sign-in tasks (kanata, Syncthing) are created with `Register-ScheduledTask` and no time limit (packages.sh `logon_task`).
- **Files on M: are owned by the old installation's account** (a different Windows SID), so git refuses every repo there ("dubious ownership"). Root-cause fix, once, elevated: `icacls M:\Eduardo /setowner Eduardo /T /C /Q`. Same will apply to any other drive carried over from the old install.
- **Some policy keys refuse `reg.exe` even as admin** ("Access is denied"): Windows 11's User Choice Protection Driver blocks reg.exe/PowerShell on them. Hit on `HKLM\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests` (Widgets); set through `gpedit.msc` instead (Widgets → Allow Widgets → Disabled), which also persists it in the local policy file.
- **Git Bash rewrites `/flags` and `C:\` paths** passed to Windows programs; scripts set `MSYS_NO_PATHCONV=1`.

### Found 2026-11-04/05

- **Git Bash's `ssh` cannot use the Bitwarden agent** (it only knows Unix sockets; Bitwarden serves a Windows named pipe), so `ssh host` asks for a password while `git` works (`core.sshCommand`). Fix in `~/.bashrc`: alias `ssh`, `scp`, `sftp`, `ssh-add`, `ssh-keygen` to `/c/Windows/System32/OpenSSH/*.exe`, sourced from `~/.bash_profile` (which also replaces the old CRLF `~/.profile`). Windows OpenSSH reads `C:\Users\Eduardo\.ssh`, not `M:\Eduardo\.ssh`.
- **GlobalProtect (UTSA VPN)** uses the default browser for SAML (`HKLM\SOFTWARE\Palo Alto Networks\GlobalProtect\Settings` `default-browser`=`yes`; UTSA's portal allows it), which is why it showed Edge until the default apps were fixed. Its service is `PanGPS` (`net start PanGPS`), the tray app `PanGPA.exe`.
- **Syncthing on DK**: the red "A socket operation was attempted to an unreachable network" is an IPv6 address being tried (home line has no IPv6); harmless. A file deleted by hand in a Receive Only folder can leave "Locally Changed Items: 1" over an empty list until a restart or the switch to Send & Receive. Keep backups of files **outside** synced folders (a `.stignore.bak` became a "local addition").
- **OneDrive exited at once** (no window, exit code `0x800704EC` "blocked by group policy"): `HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive\DisableFileSyncNGSC` = 1 was set (origin unknown; configure.sh now removes it). OneDrive came with the Microsoft 365 installer, machine-wide in `C:\Program Files\Microsoft OneDrive`. A second (personal) account is linked silently to `C:\Users\Eduardo\OneDrive` with no location prompt, despite `DisablePersonalSync`; it was empty and unlinked.
- **Work account and the PC**: signing in to Office/OneDrive offers "Allow my organization to manage my device"; answer "sign in to this app only". `dsregcmd /status` showed DK *registered* with UTSA (WorkplaceJoined YES) but **not managed** (empty `WorkplaceMdmUrl`).
- **Restic**: its `--dry-run` still reads every file (as slow as a real first backup). "unsupported file type irregular" = old **Cygwin symlinks** (Linux-style reparse points); 18 were removed or replaced by `cleanup/fix-cygwin-symlinks.sh`. "The media is write protected" reading from the shadow copy = a **cloud placeholder** (online-only file): Dropbox had left some files online-only despite "offline"; `Make available offline` on the root fixed it. Check with `attrib /s … | findstr` for `O`/`U` flags.
- **This Claude session cannot run Windows commands** (registry, `dism`, `sc`); it reads and writes files in connected folders only. For hands-on Windows administration run Claude Code in a terminal on DK; here, export settings to files under `M:\Eduardo\win-inventory\` and read them.

### Found 2026-11-06/07 (Emacs, WSL, repos)

- **Saving files into the repos from this kind of Claude session**: re-using a staging folder delivered a STALE copy (five files were silently old). Always a fresh folder per save, and check the size on the device afterwards.
- **`core.autocrlf=true`** made every Windows checkout CRLF; now `git config --global core.autocrlf input`. Never run Linux scripts from a Windows checkout under `/mnt/m` (a CRLF `apt-packages.txt` breaks `read`); WSL has its own clones.
- **Python on Windows** decodes subprocess output with cp1252 unless told otherwise: `repos.py` now reads git/gh output as UTF-8 (a repository description with "”" crashed it). Python also ignores `HOME` (takes `~` from `USERPROFILE`): `repos.py` honours `HOME`. In Git Bash, `python3` is MSYS2's (the only `python3.exe`); use `uv run --python 3.13 …` (alias `repos`).
- **MSYS2 package list**: `sqlite3` was renamed `sqlite` (the old name made pacman swap packages every run); Jinx needs `enchant` + `pkgconf`; tree-sitter grammars need `gcc`; pdf-tools uses `emacs-pdf-tools-server`.
- **OneDrive's `DisablePersonalSync` did not stop a personal account** from being linked (silently, to `C:\Users\Eduardo\OneDrive`); unlinked, empty. Not investigated further.
- **MELPA renamed its default branch to `main`** (Nov 2026) while Elpaca still clones `master`: fresh installs fail with "couldn't find remote ref master". Override of `elpaca-menu-melpa--clone` in `elisp/init.el`; existing caches (`elpaca/cache/melpa`) must be deleted once.
- **copilot.el needs track-changes ≥ 1.4**: built in on Emacs 31 (Windows), ELPA copy needed on Emacs 30 (Ubuntu 26.04).
- **WSL**: Ubuntu's login shell was bash, so `~/.zprofile` (SSH_AUTH_SOCK) never ran: `chsh -s $(command -v zsh)`. Bitwarden's agent is a Windows pipe: `prof-workstation` 04-dotfiles installs `bitwarden-agent-bridge.service` (socat + `npiperelay.exe`, Windows side `winget install -e --id albertony.npiperelay`) serving `~/.bitwarden-ssh-agent.sock`. WSLg apps use Linux fonts. The stock Emacs unit waits for a desktop session WSL never has; elisp `setup.sh` now installs a WSL variant (default.target, DISPLAY=:0, login shell), enables linger and installs `ec`.
- **`repos` unattended fetch** (hourly timer, `--no-ssh`) needs `~/.config/repos/git-credentials` (read-only fine-grained token) or a dedicated `ssh_key`; without either it skips ssh remotes.

### Earlier

- `wmic` rejects output paths containing hyphens, and is gone in Win11: use CIM via PowerShell.
- Cygwin's own `whoami` shadows `C:\Windows\System32\whoami.exe`; call Windows tools by full path where names collide. Keep MSYS2/Cygwin tools **off** the global PATH.
- `wsl --list` output is UTF-16; strip NULs (`tr -d '\0'`).
- Git for Windows' bundled ssh cannot see the Bitwarden agent pipe; Windows OpenSSH can.
- An HTTPS remote makes git ask for a password: the SSH agent is never consulted.
- Don't put licence keys in git (`.gitignore` here ignores `*.key`).
