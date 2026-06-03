#!/usr/bin/env bash
# 10-cloud — Check GitHub CLI and Google Cloud SDK auth status.
# Installation is handled by 02-brew-bundle / 03-apt-pkgs.
# Auth requires interactive login; this feature prompts and reports.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

_check_gh() {
    if ! command_exists gh; then
        warn "gh not found."
        return 1
    fi
    if gh auth status &>/dev/null; then
        info "GitHub CLI: authenticated."
    else
        warn "GitHub CLI: not authenticated."
        warn "  Run: gh auth login"
    fi
}

_check_gcloud() {
    if ! command_exists gcloud; then
        warn "gcloud not found."
        case "$OS" in
            Darwin) warn "  Install: brew install --cask google-cloud-sdk" ;;
            Linux)  warn "  Install: snap install google-cloud-sdk  or  apt-get install google-cloud-sdk" ;;
        esac
        return 1
    fi
    local account
    account="$(gcloud config get-value account 2>/dev/null)"
    if [[ -n "$account" && "$account" != "(unset)" ]]; then
        info "gcloud: authenticated as $account."
    else
        warn "gcloud: not authenticated."
        warn "  Run: gcloud auth login && gcloud auth application-default login"
    fi
}

run_step "GitHub CLI auth"       _check_gh
run_step "Google Cloud SDK auth" _check_gcloud
summary_report
