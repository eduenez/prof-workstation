# dalekanium — inventory review

Source: `M:\Eduardo\win-inventory\DALEKANIUM-20261101-1853` (snapshot taken 2026-11-01, Windows 10 Pro 22H2 build 19045).
This is the "as-is → to-be" step; the setup scripts implement what it settles.
Legend: **keep** = reinstall current version · **replace** = swap for the named alternative · **drop** = don't reinstall · **open** = still to decide.

**Decisions so far (2026-11-02):** MSYS2 replaces Cygwin; native (MSYS2) Emacs is the daily editor, WSL Emacs only for the Claude Code pane; Bitdefender + Surfshark stay (paid); Sumatra + free Adobe Reader instead of Acrobat; Notepad++, VS Code, Far Manager and current Gpg4win stay; OBS, H&R Block, LyX, TeXmacs, Apple, Adobe media and video-capture software go; printer: Brother HL-L2420 driver only; NZXT CAM only if ever needed; classic right-click menu via registry first, stock taskbar. **Open:** clipboard manager, and the numbered questions at the end.

## Hardware and install facts

| Item | Found | Consequence for the reinstall |
|---|---|---|
| CPU | AMD Ryzen 2000-series (Family 23 Model 8, 8C/16T, 3.7 GHz; likely 2700X) | On the Windows 11 supported list |
| Board / firmware | ASUS-type AMI BIOS 2801 (2019-09-18) | No update needed for Win11; fTPM lives in its setup screens |
| RAM / GPU | 32 GB; NVIDIA (driver 560.94) | Install the NVIDIA driver only, no NVIDIA App / GeForce Experience |
| Boot mode | Legacy BIOS/CSM, all internal disks MBR, `winload.exe` | Switch to UEFI-only + Secure Boot; setup makes the NVMe GPT |
| TPM | Not present (fTPM disabled) | Enable AMD fTPM in firmware setup |
| Disk 1 NVMe 477 GB | `C:` WIN10 (101 GB free) | Wiped by the clean install |
| Disk 0 SATA SSD 466 GB | `M:` MEDIA (141 GB free) **+ the 1 GB "System Reserved" boot partition** | **Unplug during install**; reconnect afterwards |
| USB | `F:` WD Elements 13 TB (9.5 TB free), `E:` WD easystore 4 TB (449 GB free) | Unplug during install; F: = Restic vault |
| Licence | Windows 10 Pro, Retail channel, activated | Carries to a clean Win11 Pro install |
| BitLocker | Off on all volumes | Answer file keeps auto device encryption off |
| Power | Sleep 30 min, display 10 min, disk 20 min, hibernate on, wake timers on, USB selective suspend on | Backup node: no sleep (or wake timers), disk-off and USB suspend **off** for F: |

## Configuration to reproduce

| Setting | Current value | Plan |
|---|---|---|
| Key remap (Scancode Map, set with SharpKeys) | Caps Lock → Left Ctrl; Scroll Lock → Caps Lock | Import the same registry value directly; SharpKeys not needed. Applies everywhere, including the login screen, WSL, and every terminal |
| Keyboard layouts | US + US-International | Same |
| Known folders → `M:\Eduardo\…` | Desktop, Documents, Downloads, Pictures, Music, Videos, Favorites, Contacts, Links, Saved Games, Searches, 3D Objects | Script the 12 registry values. AppData stays on C: (it already does; `M:\Eduardo\AppData` is a 2020 leftover) |
| `HOME` (user env) | `M:\Eduardo` | Same |
| `CYGWIN` (system env) | `nodosfilewarning` | Only if Cygwin stays |
| `OneDrive*` (user env) | Point into old `synchro\OneDrive - UTSA` | Gone; OneDrive rewrites these at sign-in |
| Explorer | Hidden + protected OS files shown, extensions shown, status bar, no recent-docs tracking, no balloon tips | Same, by script |
| Taskbar | Small icons, Task View button, no Cortana | Win11 has no small-icon taskbar; see "Windows 11 shell" below |
| Windows Update policy | Download automatically, ask before install (AUOptions 3); no reboot while logged on | Same, plus **exclude drivers** (blocks unattended BIOS/firmware updates) and defer feature updates |
| Office policy | Copilot pinning **on** (pushed by M365) | Copilot app removed + policies off |
| Fonts (user) | Input Mono (full family), Iosevka Slab / Term Slab, Latin Modern Math, STIX Two, Roboto Mono | Copy from the old user-fonts folder; keep a copy in `M:\Eduardo\fonts` |
| Windows Terminal | Default profile Leap 15.6, font Input Mono, size 20 | Settings file kept in the repo |
| mintty | `FontHeight=16`, `Rows=40`, `BoldAsFont=yes` | Same file, if mintty stays (Cygwin or MSYS2) |
| Git (`M:\Eduardo\.gitconfig`) | `autocrlf = true`, editor = VS Code, `sshCommand` = Windows OpenSSH, `insteadOf` SSH | Fix: `autocrlf = input` (repos shared with Macs/Linux), editor = `emacsclient`, typo `[cerendial]` → `[credential]`, keep the rest. Email is `eduenez@gmail.com` here; the template on the Macs takes it from the prompt |
| Autostart | 25 Run entries (Apple ×4, Adobe ×4, Epson ×2, Brother ×2, Java updater, ArcSoft, Bitdefender ×2, Surfshark, Docker, Boxcryptor, GOG…) | Only the sync apps, Bitwarden, the clipboard manager, Syncthing |

### PATH (current, de-duplicated)

System: `C:\Perl64\site\bin`, `C:\Perl64\bin`, Oracle Java javapath, Windows dirs (listed twice, once literal and once via `%SystemRoot%`), NVIDIA PhysX, Asymptote 2.61, MiKTeX 2.9, Git 2.24 `cmd`, PuTTY, GnuPG, PDFtk, Calibre, Docker ×2, LyX's Perl, Boxcryptor, dotnet, PowerToys DSC, WSL, GitHub CLI.
User: `WindowsApps`, `M:\Eduardo\bin`, Ghostscript 9.50, GitHub Desktop.

Plan: the system PATH holds only Windows itself and the tools installers add (Git, gh, TeX Live, Ghostscript, Asymptote). The user PATH holds `M:\Eduardo\bin` first. **Unix tools (MSYS2 or Cygwin) do not go on the global PATH**, because `find`, `sort` and similar would shadow Windows' own tools for every program. They go on Emacs's `exec-path` and inside the shells that want them.

## Software triage

### Core — keep

| Program | Now | Note |
|---|---|---|
| Firefox, Chrome | current | |
| Bitwarden | 2026.10 | SSH agent for git (`IdentityAgent` pipe) |
| Dropbox | 277 | Only while the `Apps/` remnant lives |
| Google Drive | 133 | Into `M:\Eduardo\GoogleDrive` |
| Tresorit (+ Outlook add-in) | 3.5 | Into `M:\Eduardo\Tresorit` |
| OneDrive (UTSA) | current | Into `M:\Eduardo\OneDrive - …`; personal OneDrive off |
| Cryptomator + WinFsp | 1.19 / 2025 | `secreto` vault |
| Microsoft 365 Apps (UTSA), Teams (new) | | The reason this machine stays Windows |
| Adobe Acrobat (+ Reader) | 25 | Install SumatraPDF and free Adobe Reader only. |
| Git for Windows, GitHub CLI | 2.24 (2020!) / 2.103 | Git current version |
| 7-Zip | **two** copies (19.00 and 23.01) | One, current |
| VLC, IrfanView, SumatraPDF | | Sumatra 3.1 → current (also reads DjVu) |
| calibre, PDFtk, kdiff3 | | |
| PowerToys | 0.96 | Useful bits: PowerRename, FancyZones, Peek, Command Palette. Not Keyboard Manager (registry remap is better) |
| Zoom, WhatsApp (Store) | | |
| Claude desktop | | |
| All the Unicode (Store), BabelMap | | See "Unicode input" below |
| NVIDIA driver | 560.94 | Driver only |
| Wacom driver | 6.3 | If the tablet is still used |

### New

Syncthing, Restic, **TeX Live** (replaces MiKTeX, matching the other machines), current Ghostscript and Asymptote, **MSYS2** (Emacs + Unix tools; replaces Cygwin), WinCompose, and a clipboard manager (open, see below).

### Replace or update

| Program | Now | Replacement |
|---|---|---|
| MiKTeX 2.9 + 20.7 (two installs) | 2020 | TeX Live (same distribution as the Macs and Ubuntu; `latexmkrc` already in the repo) |
| ActivePerl 5.28 | 2020 | Drop: TeX Live ships its own Perl, and WSL has it |
| Anaconda3 2019.10, Store Python 3.8 | | **uv**, as in `prof-workstation`; heavy Python work goes in WSL |
| SageMath 9.0 (Windows) | 2020 | In WSL (`apt`/conda); Sage stopped shipping a Windows installer |
| Docker Desktop 2.3 | 2020 | Docker Engine inside WSL, only if needed |
| VirtualBox 6.1 | 2020 | Hyper-V is already on. |
| Gpg4win 3.1.11 / GnuPG 2.2 | 2019 | Current Gpg4win. |
| GSview 5, WinDjView, MPC-HC 1.7 | | Sumatra and VLC cover them |
| PuTTY, ConEmu | | Windows OpenSSH + Windows Terminal |
| Far Manager 3, Total Commander 9 |  | Keep Far (closest Windows analogue of `mc`); drop Total Commander |
| Notepad++ | 8.6 | Notepad++ current + Emacs |
| VS Code 1.41 | 2020 | Current version. |
| OBS 25 | 2020 | Drop |
| ArsClip | 2020; development stopped years ago | Open: ClipMate, Ditto or CopyQ (see below) |
| SharpKeys | | Not needed: the remap is a registry import |
| H&R Block 2020–2025 | six installs | Drop |

### Drop (stale, dead, or redundant)

Boxcryptor (service discontinued), BIG-IP Edge Client (old UTSA VPN), Teams classic + machine-wide installer, Webex, Panopto, SoftChalk, MEDIALecture, Visual Studio 2019 + Windows SDK + Application Verifier + HTML Help Workshop + SQL CLR types (unless you build Windows software), Java 8 (unless something needs it), Pdf995/PdfEdit995 (H&R add-ons), Brother PowerENGAGE, Epson Software Updater, Dell OS Recovery Tool and HP Cloud Recovery (tools for other machines), Windows Journal, Copilot (installed by Microsoft on 2026-11-01), the Store junk (Candy Crush, Farm Heroes, Solitaire, Bing, Xbox apps, Skype, People, Mixed Reality, 3D Viewer, Print 3D, Wallet, Your Phone/Phone Link…), Norton remnants, Apple Software Update.

### You decide

| Group | Programs | Question |
|---|---|---|
| Security | Bitdefender Total Security + VPN, Surfshark | Install both (paid subscription). Setup adds Bitdefender scan exclusions for `M:\Eduardo\synchro`, `M:\Eduardo\secreto` and the Restic repo on F:, and allows Syncthing through its firewall |
| Apple | iCloud (Drive, Photos), iTunes, Bonjour | Not really used on Windows |
| Adobe media | Creative Cloud, Premiere Pro / Media Encoder / Rush 2020 | Don't install |
| Video capture | EzGrabber, Conexant USB 2.0 capture, ArcSoft ShowBiz, CyberLink PowerDirector 12 | Drop all |
| Scanners and printers | Brother iPrint&Scan, Epson Scan 2 / ScanSmart / Event Manager, Canon LiDE 300 + IJ Scan, Canon Inkjet Print (Store) | Only have Brother HL-L2420 printer |
| Cooling | NZXT CAM 4.21 | Never actively used; install if needed |
| Diagnostics | CPU-Z, GPU-Z, FurMark | On demand |
| Games and launchers | Steam, GOG Galaxy, Minecraft Education, ~25 titles | Default: launchers on demand, games through them; saves are already in `M:\Eduardo\Saved Games` |
| Authoring | LyX 2.3, TeXmacs 1.99 | Drop |
| Misc | MicroDicom, FileZilla, GitHub Desktop, Opera, File Viewer Plus, Google Voice | Default: drop (on demand) |

## Emacs on Windows 11

The repo's Emacs config (`eduenez/elisp`: Elpaca, eglot, `claude-code-ide.el` with `eat`) assumes a Unix host. On this machine today Emacs is a 2020 build in `C:\Program Files\emacs`, and `M:\Eduardo\.emacs` is still the SuSE skeleton loading `~/synchro/emacs.d`.

| Option | Strengths | Weaknesses |
|---|---|---|
| **A. Native Windows Emacs, from MSYS2 (UCRT64)** | Real Windows GUI: Alt=Meta, Ctrl, clipboard, fonts and HiDPI all just work; files on M: at native speed; native compilation included; `pacman` keeps Emacs **and** its helper tools (git, ripgrep, aspell/hunspell, gnupg, find/grep, diff) updated and listed in one manifest, like apt | Starting subprocesses is slow on Windows (magit noticeably slower); **`eat` and `vterm` need a Unix PTY and don't run on native Windows**, so the `claude-code-ide` pane doesn't work there |
| **B. Emacs in WSL, GUI via WSLg (pgtk build)** | Same Linux Emacs as chatedg; `eat`/`claude-code-ide` work; a pgtk (Wayland) build avoids the X11 keyboard-mapping layer where your Alt/Ctrl trouble likely came from | Still a remote-desktop-backed window: occasional focus, scaling and clipboard quirks; files on M: go through the slow `/mnt/m` bridge |
| **C. Terminal Emacs in WSL inside Windows Terminal** | Simplest; Alt=Meta works | Terminals can't deliver some chords (`C-;`, `C-,`, `C-RET`, `C-S-…`); no GUI features |

**Accept recommendation:** A as the daily editor for everything on M:, sharing the same `elisp` repo (it is already OS-aware), with `emacsclient` as git's editor. Use B only for the Claude Code pane and WSL-side projects. MSYS2 is adopted for Emacs's tools, so Cygwin could retire.

## Unicode input

You have All the Unicode (Store) and BabelMap: good for browsing and search, but mouse-driven. **WinCompose** (open source) adds an X11-style Compose key: e.g. `Compose = >` → `⇒`, `Compose * a` → `α`, with sequences you define in a plain-text `.XCompose` file, the same file format Linux uses. Keep All the Unicode for browsing, add WinCompose for typing, and inside Emacs use the `TeX` input method and `C-x 8 RET`. Windows' own `Win+.` panel has a Symbols tab as a fallback.

## Clipboard manager

**CopyQ** is open source and runs on Windows, macOS and Linux, so the same tool, shortcuts and config work on every machine. It has searchable history, tabs, pinned items and scripting. Ditto (Windows-only, mature) is the alternative if you only care about this machine.
I use ClipMate in MacOS and absolutely love it; I'm not leaving it behind, so cross-platform is less important. I see that people like ditto in Windows better. I'm willing to pay for a excellent clipboard manager, if options are superior to free ones.

## Windows 11 shell

Win11 removed small taskbar icons, top/side taskbar placement, and the classic right-click menu (the full menu is behind "Show more options"). The classic menu comes back with one registry key, which the setup will set. The taskbar can't be restored natively. Third-party options: **ExplorerPatcher** (open source; breaks occasionally after big Windows updates, and Defender sometimes flags it) or StartAllBack (paid, polished). Or live with the stock taskbar, aligned left, with widgets, search box, Task View and Copilot removed.

Me: Let's try to classic menu regkey first; see how I like it.