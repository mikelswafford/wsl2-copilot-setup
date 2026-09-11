# wsl2-copilot-setup

Scripts and instructions for authenticating `gh`, `git`, and the
[GitHub Copilot CLI](https://github.com/github/copilot-cli) as a **GitHub
App installation** instead of a personal account, so a machine (e.g. a
fresh WSL2 instance) can push/pull, open PRs, and run Copilot CLI without
ever storing a personal access token.

## Why

Personal access tokens cached by git's `store`/`cache` credential helpers
are long-lived, broad-scoped, and tied to your personal account. A GitHub
App installation token is short-lived (1 hour), scoped to only the
repos/permissions the App was installed with, and mints a fresh token
per use. This repo wires that up for:

- `gh-app` - wraps the `gh` CLI, injecting a fresh installation token
- `github-app-credential` - a git credential helper backed by the same
  token source, so plain `git push`/`git pull`/`git fetch` also
  authenticate as the App
- `copilot-app` - wraps the Copilot CLI, using GitHub's OAuth device flow
  against a GitHub App client ID (a separate, user-authorization-based
  flow, since Copilot CLI authenticates as a user, not an installation)

## What's NOT in this repo

Nothing instance-specific or secret. You must supply, on your own
machine, outside of any repo:

- A GitHub App you've created and installed (its App ID, Installation
  ID, and private key)
- The private key (`.pem`) file itself
- Any resulting cached tokens

These are read from environment variables and local files that live
outside this repo (see Setup below).

## Setup

1. Clone this repo and run the installer:

   ```bash
   git clone https://github.com/Bamboo-Forge-Games/wsl2-copilot-setup.git
   cd wsl2-copilot-setup
   ./install.sh
   ```

   This copies the scripts into `~/.local/bin`. Make sure that directory
   is on your `PATH` (add `export PATH="$HOME/.local/bin:$PATH"` to your
   `~/.bashrc`/`~/.profile` if it isn't already).

2. Install required tools/libraries:

   ```bash
   sudo apt-get install -y jq util-linux curl python3 python3-pip gnupg
   pip3 install --user PyJWT requests cryptography
   ```

   You'll also need the `gh` CLI (https://cli.github.com) and Node.js +
   the Copilot CLI (`npm install -g @github/copilot`) if you plan to use
   `copilot-app`.

3. Create a GitHub App (or reuse an existing one):
   - Go to your GitHub organization (or personal account) Settings ->
     Developer settings -> GitHub Apps -> New GitHub App.
   - Grant it the repository permissions you need (e.g. Contents:
     Read & write, Pull requests: Read & write).
   - After creating it, generate and download a private key
     (`<app-name>.<date>.private-key.pem`).
   - Install the App on the org/repos you want to automate. Note the
     **App ID** (shown on the app's settings page) and the
     **Installation ID** (the numeric ID in the URL when viewing the
     installation, e.g.
     `https://github.com/settings/installations/<installation-id>`).

4. Store the private key somewhere private (never inside a git repo):

   ```bash
   mkdir -p ~/.github-apps
   mv ~/Downloads/your-app.*.private-key.pem ~/.github-apps/app.pem
   chmod 600 ~/.github-apps/app.pem
   ```

5. Set the required environment variables, e.g. in `~/.bashrc`:

   ```bash
   export GH_APP_ID=123456
   export GH_APP_INSTALLATION_ID=987654321
   export GH_APP_PRIVATE_KEY_PATH="$HOME/.github-apps/app.pem"
   ```

6. Use `gh-app` in place of `gh` for any GitHub CLI operation:

   ```bash
   gh-app pr create --title "..." --body "..."
   gh-app pr view 123 --comments
   ```

7. (Optional, recommended) Point plain `git` at the same App-based
   credentials, so `git push`/`git pull`/`git fetch` don't need `gh-app`
   at all:

   ```bash
   git config --global credential.helper '!github-app-credential'
   ```

   **Important:** if you previously configured a personal-access-token
   credential helper (e.g. `git config --global credential.helper store`
   or `cache`), remove it and delete any file it cached credentials in
   (commonly `~/.git-credentials` or a `pass`/`password-store` file you
   pointed it at). Git tries credential helpers in the order they're
   configured and stops at the first one that returns a credential, so a
   stale personal-token helper listed first will silently keep being used
   even after you add `github-app-credential`.

8. To use the Copilot CLI via the GitHub App's OAuth device flow, just
   run:

   ```bash
   copilot-app
   ```

   The first run will print a URL and a one-time code to authorize the
   App interactively; afterwards it silently refreshes its token on each
   run (state is kept in
   `~/.local/state/copilot-app-auth/tokens.json`, mode `600`).

## Verifying it worked

```bash
gh-app auth status        # or: gh-app api /installation/repositories
git ls-remote origin HEAD # should succeed with no personal credentials cached
```

## Files

| File | Purpose |
|---|---|
| `bin/get-github-app-token.py` | Mints a short-lived (`ghs_...`) installation access token from the App ID, Installation ID, and private key. |
| `bin/gh-app` | Wraps `gh`, injecting a fresh token via `GH_TOKEN` per invocation. |
| `bin/github-app-credential` | Git credential helper backed by the same token source. |
| `bin/copilot-app` | Wraps the `copilot` CLI, using GitHub's OAuth device flow (a separate, user-authorization-based token, since Copilot CLI authenticates as a user rather than an installation) with automatic refresh. |
| `install.sh` | Copies the scripts above into `~/.local/bin` and prints the remaining manual setup steps. |

## Security notes

- The private key and any token/state files are never read from or
  written to this repo; they live under `~/.github-apps/` and
  `~/.local/state/` respectively, both outside version control.
- `get-github-app-token.py` requires `GH_APP_ID` and
  `GH_APP_INSTALLATION_ID` to be set and fails loudly if they aren't,
  rather than silently falling back to any default.
- Installation tokens (`ghs_...`) expire after 1 hour; nothing here
  caches them to disk.
- The Copilot CLI OAuth refresh token is cached to disk
  (`~/.local/state/copilot-app-auth/tokens.json`, mode `600`) because
  GitHub's OAuth device flow issues a rotating refresh token, not a
  short-lived-only credential; treat that file as a secret.
