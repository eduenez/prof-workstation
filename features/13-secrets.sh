#!/usr/bin/env bash
# 13-secrets — Print the manual checklist for credentials.
# Nothing is automated here; credentials are never stored in this repo.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

cat <<'CHECKLIST'

  ┌─────────────────────────────────────────────────────┐
  │         Secrets & Credentials Checklist             │
  └─────────────────────────────────────────────────────┘

  The following steps require manual action.

  [ ] 1. Bitwarden + SSH agent
          Install the Bitwarden desktop app, log in, and enable its SSH agent
          (Settings → SSH agent). SSH keys live in the vault, not in ~/.ssh;
          zprofile and ssh_config already point at ~/.bitwarden-ssh-agent.sock.
          Check:  ssh -T git@github.com

  [ ] 2. GitHub CLI
          gh auth login -h github.com --git-protocol ssh --web --skip-ssh-key
          (SSH: git remotes use the Bitwarden key, already on GitHub.
           Required for Copilot in Emacs and VS Code.)

  [ ] 3. Google Cloud
          gcloud auth login
          gcloud auth application-default login

  [ ] 4. Emacs Copilot
          Launch Emacs → M-x copilot-login

  [ ] 5. API keys (retrieve from Bitwarden; add to ~/.zshrc.local)
          export ANTHROPIC_API_KEY=...
          export OPENAI_API_KEY=...
          export GEMINI_API_KEY=...
          export GOOGLE_CLOUD_PROJECT=...

  [ ] 6. Bitwarden browser extension
          Chrome Web Store or Firefox Add-ons.

  [ ] 7. Ollama models
          ollama pull llama3.2
          (Pull whichever models you use.)

CHECKLIST

info "Checklist printed. No automated actions taken."
