# dalekanium — Windows 10 → clean Windows 11 reinstall

Handoff document: everything a later session (human or agent) needs to resume this work cold.
Companion files in this directory: `review.md` (the agreed as-is → to-be decisions, item by item).
Scripts: `../inventory.sh` (read-only capture), `../prewipe-backup.sh` (safety copies before the wipe).

## Status (2026-11-02)

- [x] Git over SSH on dalekanium works (Bitwarden agent via Windows OpenSSH; `url.insteadOf` rewrite)
- [x] Inventory captured: `M:\Eduardo\win-inventory\DALEKANIUM-20261101-*` (2343 is the complete one; 1853 also holds the **driver export**, `drivers\`, ~2 GB)
- [x] Review done and decisions recorded in `review.md`
- [x] `delfincito-pc` renamed `dalekanium` throughout `filetree-reorg`
- [ ] Run `prewipe-backup.sh copy`, then `image` (to `F:\dalekanium-prewipe`)
- [ ] Download the install media (below)
- [ ] **Before the wipe: write the one-page printable walk-through** (firmware → install → first boot → reconnect), from Phases 2–4 below, and print it
- [ ] Phases 2–7
- [ ] Afterwards: update `filetree-reorg` docs where they still describe dalekanium as "Windows 10, sleeps after active use" and assume `%USERPROFILE%\synchro` (it will be `M:\Eduardo\synchro`)

## Machine facts that drive the plan

- ASUS ROG STRIX B450-F GAMING, BIOS 2801 (2019), Ryzen 7 2700X (on the Win11 supported list), 32 GB, NVIDIA GPU, Intel LAN.
- Boots **legacy BIOS/CSM**, disks **MBR**, **no TPM** active → firmware changes needed (Phase 2).
- Disks: NVMe 477 GB = `C:` (wiped). SATA SSD 466 GB = `M:` (data, survives) **and holds the 1 GB "System Reserved" boot partition**. USB: `F:` WD Elements 13 TB (Restic vault, pre-wipe backup), `E:` WD easystore 4 TB.
- Windows 10 Pro **Retail**, activated → Win11 Pro activates on reinstall without a Microsoft account.
- `HOME=M:\Eduardo`; 12 known folders already point to `M:\Eduardo\…`; AppData stays on C:.

## Install media (download on dalekanium while still on Windows 10)

1. **Windows 11 ISO**, x64, current release (26H2 as of autumn 2026), from Microsoft's "Download Windows 11" page → section "Download Windows 11 Disk Image (ISO) for x64 devices", edition "Windows 11 (multi-edition ISO)", language English (United States).
2. **Rufus** (portable .exe, rufus.ie). Write the ISO to a USB stick of **≥ 8 GB, which gets erased**. Partition scheme **GPT**, target **UEFI (non CSM)**. In Rufus's "Windows User Experience" dialog tick: remove the online Microsoft-account requirement, create a local account named `Eduardo`, disable data-collection questions, **disable BitLocker automatic device encryption**. Leave the TPM/Secure Boot bypass **unticked** (this machine will meet both once Phase 2 is done).
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
- Boot → Secure Boot → OS Type **Windows UEFI mode**.
- Do **not** update the BIOS unless a concrete problem appears (e.g. fTPM-related stutter, fixed in later AMD firmware); if so, do it deliberately and supervised.

### 3. Install
- Power off. **Unplug the SATA cable of the M: SSD**, and both USB drives. Only the NVMe and the Rufus stick remain.
- Boot the stick (`F8` boot menu), choose the UEFI entry. Delete all partitions on the NVMe, install to the unallocated space (setup creates GPT + EFI partition there).
- First boot: local account `Eduardo` (from the Rufus answer file), privacy questions answered "no"/skipped.
- Power off, reconnect M:, F:, E:. Check drive letters in Disk Management (`M:`, `F:`, `E:`); fix if needed. The old System Reserved partition on the M: disk is now unused; leave it.

### 4. First boot essentials (manual, before any script)
- Activation check (Settings → System → Activation).
- Install Git for Windows and Bitwarden; enable the Bitwarden SSH agent; make sure the "OpenSSH Authentication Agent" service is **Disabled**.
- `setx HOME M:\Eduardo`; `git config --global core.sshCommand C:/Windows/System32/OpenSSH/ssh.exe` (or the `.gitconfig` on M: already carries it).
- `cd M:\Eduardo\repos\prof-workstation && git pull` — from here the setup scripts take over.

### 5. Windows configuration (scripted: to be written as `windows/setup/*`)
Policy and registry, in this order: Windows Update (download automatically, ask before install, no reboot while logged on, **exclude drivers**, defer feature updates) → remove Copilot/widgets/ads/Spotlight/Start suggestions/telemetry where Pro allows → OneDrive personal off (policy) → Scancode Map (Caps→Left Ctrl, Scroll Lock→Caps) → known folders → Explorer settings → classic context menu → keyboard layouts (US + US-International) → power (sleep, hibernate off, wake timers on, USB selective suspend off) → fonts from the saved user-fonts folder → restore drivers if any device is missing (`pnputil /add-driver M:\Eduardo\win-inventory\DALEKANIUM-20261101-1853\drivers\*.inf /subdirs /install`).

### 6. Software (scripted: `winget` manifest + MSYS2 `pacman` list), per `review.md`
Bitdefender Total Security (no VPN), Surfshark, browsers, sync apps (OneDrive UTSA, Tresorit, Google Drive, Dropbox — rename old folders first, see below), Cryptomator + WinFsp, Office/Teams, Git, gh, MSYS2 (Emacs, Unix tools, mintty, openssh), TeX Live, Ghostscript, Asymptote, Total Commander, Far Manager, Notepad++, VS Code, VLC, IrfanView, SumatraPDF, Adobe Reader, calibre, PDFtk, kdiff3, PowerToys, Ditto, WinCompose, All the Unicode, Gpg4win, Zoom, WhatsApp, Claude, NVIDIA driver only, Wacom driver, Brother HL-L2420DW driver. WSL: Ubuntu 26.04 LTS (stored on M:), `prof-workstation` Linux features inside it. Emacs: native MSYS2 build as daily editor, shared `elisp` repo; WSL Emacs only for the Claude Code pane.

Old sync folders, before installing those apps: `M:\Eduardo\synchro\OneDrive - University of Texas at San Antonio` → `M:\Eduardo\`, `M:\Eduardo\synchro\private` → `M:\Eduardo\Tresorit-old` (Tresorit then syncs fresh into `M:\Eduardo\Tresorit`), remainder of `M:\Eduardo\synchro` → `M:\Eduardo\synchro-legacy`. This frees `M:\Eduardo\synchro` for Syncthing.

### 7. Backup node (per `filetree-reorg/design/syncthing_setup.md` and `restic_backup.md`, Phase 4)
Syncthing: pair with the mesh (Studio accepts the pending device), folders `synchro` and `secreto` at `M:\Eduardo\…`, versioning Simple/keep 3, `Thumbs.db` sweep task. Restic: independent repo on `F:`, own password, run by a Task Scheduler job that **wakes the PC**, holds it awake, waits for Syncthing to be idle, backs up, then sleeps it again. Bitdefender: exclude `synchro`, `secreto`, the Restic repo; allow Syncthing through its firewall. Restore test before calling it done.

## Gotchas already found

- `wmic` rejects output paths containing hyphens, and is gone in Win11: use CIM via PowerShell.
- Cygwin's own `whoami` shadows `C:\Windows\System32\whoami.exe`; call Windows tools by full path where names collide. Keep MSYS2/Cygwin tools **off** the global PATH.
- `wsl --list` output is UTF-16; strip NULs (`tr -d '\0'`).
- Git for Windows' bundled ssh cannot see the Bitwarden agent pipe; Windows OpenSSH can.
- An HTTPS remote makes git ask for a password: the SSH agent is never consulted.
- Don't put licence keys in git (`.gitignore` here ignores `*.key`).
