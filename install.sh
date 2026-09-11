#!/usr/bin/env bash
# Installs the gh-app-bootstrap scripts into ~/.local/bin and prints the
# remaining manual setup steps (creating/installing a GitHub App, placing
# its private key, and setting the required environment variables).
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install_dir="${HOME}/.local/bin"

mkdir -p "$install_dir"
install -m 755 "$repo_dir"/bin/* "$install_dir"/

cat <<'EOF'

Installed to ~/.local/bin:
  gh-app                 - wraps `gh`, authenticating as a GitHub App installation
  copilot-app            - wraps `copilot`, authenticating via GitHub OAuth device flow
  github-app-credential  - git credential helper backed by the same GitHub App
  get-github-app-token.py - shared token-minting script used by the above

Remaining manual steps (see README.md for full details):

  1. Ensure ~/.local/bin is on your PATH.
  2. Create a GitHub App and install it on the org/repos you want to
     automate, then note its App ID and Installation ID.
  3. Download the App's private key and save it somewhere private, e.g.:
       mkdir -p ~/.github-apps
       mv ~/Downloads/your-app.*.private-key.pem ~/.github-apps/app.pem
       chmod 600 ~/.github-apps/app.pem
  4. Add to your shell profile (e.g. ~/.bashrc):
       export GH_APP_ID=<your app id>
       export GH_APP_INSTALLATION_ID=<your installation id>
       export GH_APP_PRIVATE_KEY_PATH="$HOME/.github-apps/app.pem"
  5. (Optional, recommended) Make git itself use the GitHub App instead of
     any personal credentials:
       git config --global credential.helper '!github-app-credential'
     Also remove any pre-existing personal-access-token credential helper
     (e.g. `store`/`cache`) and any cached token file it created, so it
     cannot shadow the App-based helper.
  6. Install Python dependencies: pip3 install --user PyJWT requests cryptography
  7. To use Copilot CLI via the App-based OAuth flow, run `copilot-app`
     once and follow the device authorization prompt.

EOF
