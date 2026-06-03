#!/usr/bin/env bash
# 12-macos-prefs — macOS system preferences via defaults write.
# Finder and Dock are restarted at the end to apply changes.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

if [[ "$OS" != "Darwin" ]]; then
    info "macOS only — skipping on $OS."
    exit 0
fi

_prefs_finder() {
    defaults write com.apple.finder AppleShowAllFiles                -bool  true
    defaults write NSGlobalDomain   AppleShowAllExtensions           -bool  true
    defaults write com.apple.finder ShowStatusBar                    -bool  true
    defaults write com.apple.finder ShowPathbar                      -bool  true
    defaults write com.apple.finder _FXSortFoldersFirst              -bool  true
    defaults write com.apple.finder FXDefaultSearchScope             -string "SCcf"
    defaults write com.apple.finder WarnOnEmptyTrash                 -bool  false
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.desktopservices DSDontWriteUSBStores    -bool  true
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool  true
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint    -bool  true
}

_prefs_keyboard() {
    # Fast key repeat — essential for Emacs-style navigation.
    defaults write NSGlobalDomain KeyRepeat             -int   2
    defaults write NSGlobalDomain InitialKeyRepeat      -int   15
    defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
    # Disable autocorrections that mangle code and math.
    defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled  -bool false
    defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled      -bool false
    defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled  -bool false
    defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled    -bool false
    defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled   -bool false
}

_prefs_dock() {
    defaults write com.apple.dock autohide       -bool  true
    defaults write com.apple.dock autohide-delay -float 0.1
    defaults write com.apple.dock show-recents   -bool  false
    defaults write com.apple.dock tilesize       -int   48
    defaults write com.apple.dock launchanim     -bool  false
}

_prefs_screenshots() {
    defaults write com.apple.screencapture location       -string "$HOME/Desktop"
    defaults write com.apple.screencapture disable-shadow -bool   true
    defaults write com.apple.screencapture type           -string "png"
}

_prefs_misc() {
    # Show the ~/Library folder
    chflags nohidden ~/Library
    # Show the /Volumes folder (requires sudo, but we don't block for it)
    sudo chflags nohidden /Volumes 2>/dev/null || true
    # Disable the "Are you sure you want to open this application?" dialog
    defaults write com.apple.LaunchServices LSQuarantine -bool false
}

_restart_ui() {
    info "Restarting Finder and Dock..."
    killall Finder 2>/dev/null || true
    killall Dock   2>/dev/null || true
}

run_step "Finder"      _prefs_finder
run_step "Keyboard"    _prefs_keyboard
run_step "Dock"        _prefs_dock
run_step "Screenshots" _prefs_screenshots
run_step "Misc"        _prefs_misc
_restart_ui

summary_report
