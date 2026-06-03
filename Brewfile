# Brewfile — All Homebrew packages, casks, and fonts.
# Run with: brew bundle --file=Brewfile --no-lock --no-upgrade
#
# Notable large installs:
#   mactex-no-gui  ~5 GB  — full TeX Live without GUI apps
#   sage           ~1 GB  — standalone SageMath (isolated; do not mix with uv Python)

# ── Core Unix tools ───────────────────────────────────────────────────
brew "coreutils"         # GNU fileutils, textutils (gls, gcp, gdate, …)
brew "gnu-sed"
brew "gnu-tar"
brew "gawk"
brew "findutils"         # GNU find, locate, xargs
brew "grep"
brew "wget"
brew "curl"
brew "git"
brew "git-lfs"
brew "tmux"
brew "htop"
brew "tree"
brew "ripgrep"
brew "fd"
brew "bat"
brew "fzf"
brew "jq"
brew "yq"
brew "zstd"
brew "xz"
brew "p7zip"
brew "mc"                # Midnight Commander

# ── Development tools ─────────────────────────────────────────────────
brew "gh"                # GitHub CLI
brew "automake"
brew "autoconf"
brew "cmake"
brew "pkg-config"
brew "libtool"
brew "opam"              # OCaml package manager

# ── Languages and runtimes ────────────────────────────────────────────
brew "node"
brew "rbenv"
brew "ruby-build"
brew "r"
brew "sbcl"              # Steel Bank Common Lisp
brew "uv"                # Python version + virtualenv manager (replaces pyenv + pip)

# ── Emacs dependencies ────────────────────────────────────────────────
brew "enchant"           # multi-backend spell checking (flyspell)
brew "aspell"            # aspell backend + English dictionary
brew "poppler"           # pdf-tools
brew "imagemagick"       # image display in Emacs buffers
brew "djvulibre"         # DjVu support

# ── LaTeX and typesetting ─────────────────────────────────────────────
cask "mactex-no-gui"     # full TeX Live without GUI apps
brew "pandoc"
brew "gnuplot"
brew "asymptote"
brew "texlab"            # LaTeX LSP for Emacs + VS Code

# ── Publishing / document utilities ──────────────────────────────────
brew "ghostscript"
brew "graphviz"
brew "ffmpeg"
brew "yt-dlp"
cask "skim"              # PDF reader with SyncTeX support

# ── Cloud tools ───────────────────────────────────────────────────────
cask "google-cloud-sdk"

# ── AI tools ─────────────────────────────────────────────────────────
cask "ollama"
brew "asitop"            # GPU/ANE monitoring for Apple Silicon

# ── Fonts (Nerd Fonts) ────────────────────────────────────────────────
cask "font-jetbrains-mono-nerd-font"
cask "font-ibm-plex-mono-nerd-font"
cask "font-iosevka-nerd-font"
cask "font-symbols-only-nerd-font"  # icon-only fallback for nerd-icons

# ── Terminal ──────────────────────────────────────────────────────────
cask "iterm2"

# ── Editors and IDE ───────────────────────────────────────────────────
cask "emacs"
cask "visual-studio-code"

# ── Browsers ──────────────────────────────────────────────────────────
cask "google-chrome"
cask "firefox"
cask "brave-browser"

# ── Communication ─────────────────────────────────────────────────────
cask "signal"
cask "whatsapp"
cask "zoom"

# ── Media ─────────────────────────────────────────────────────────────
cask "vlc"

# ── System utilities ──────────────────────────────────────────────────
cask "karabiner-elements"
cask "xquartz"

# ── Modern CLI Alternatives ───────────────────────────────────────────
brew "tealdeer"          # tldr
brew "dust"              # du replacement
brew "procs"             # ps replacement

# ── Math (isolated) ───────────────────────────────────────────────────
cask "sage"              # standalone SageMath; carries its own Python — never mix with uv
brew "elan-init"         # Lean 4 version manager
brew "z3"                # SMT solver for AI/Logic
brew "julia"

# ── Research Apps (Casks) ─────────────────────────────────────────────
cask "zotero"
cask "mathpix-snipping-tool"
cask "ipe"               # Math-focused drawing tool
cask "obsidian"          # Knowledge management / research notes
