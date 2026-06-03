#!/usr/bin/env bash
# 13-secrets — Print the manual checklist for credentials.
# Nothing is automated here; credentials are never stored in this repo.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

cat <<'CHECKLIST'

  ┌─────────────────────────────────────────────────────┐
  │         Secrets & Credentials Checklist             │
  └─────────────────────────────────────────────────────┘

  The following steps require manual action.

  [ ] 1. SSH keys
          Copy ~/.ssh/id_* and ~/.ssh/config from the old machine.
          chmod 600 ~/.ssh/id_*  &&  chmod 644 ~/.ssh/*.pub

  [ ] 2. GitHub CLI
          gh auth login
          (Required for Copilot in Emacs and VS Code.)

  [ ] 3. Google Cloud
          gcloud auth login
          gcloud auth application-default login

  [ ] 4. Emacs Copilot
          Launch Emacs → M-x copilot-login

  [ ] 5. API keys (retrieve from LastPass; add to ~/.zshrc.local)
          export ANTHROPIC_API_KEY=...
          export OPENAI_API_KEY=...
          export GEMINI_API_KEY=...
          export GOOGLE_CLOUD_PROJECT=...

  [ ] 6. LastPass browser extension
          Chrome Web Store or Firefox Add-ons.

  [ ] 7. Ollama models
          ollama pull llama3.2
          (Pull whichever models you use.)

CHECKLIST

info "Checklist printed. No automated actions taken."
