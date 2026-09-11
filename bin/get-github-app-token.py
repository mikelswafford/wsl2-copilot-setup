#!/usr/bin/env python3
"""Mints a short-lived GitHub App installation access token and prints it.

Requires the following environment variables to be set:
  GH_APP_ID                 - the GitHub App's numeric App ID
  GH_APP_INSTALLATION_ID    - the numeric installation ID for the target
                               org/repo(s)
  GH_APP_PRIVATE_KEY_PATH   - path to the App's private key (.pem) file
                               (defaults to ~/.github-apps/app.pem)
"""

import os
import sys
import time

import jwt
import requests


def _require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        print(f"Required environment variable not set: {name}", file=sys.stderr)
        sys.exit(1)
    return value


def main() -> None:
    app_id = _require_env("GH_APP_ID")
    installation_id = _require_env("GH_APP_INSTALLATION_ID")
    private_key_path = os.environ.get(
        "GH_APP_PRIVATE_KEY_PATH",
        os.path.expanduser("~/.github-apps/app.pem"),
    )

    try:
        with open(private_key_path, "r") as f:
            private_key = f.read()
    except OSError as exc:
        print(
            f"Could not read GitHub App private key at {private_key_path}: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)

    now = int(time.time())
    payload = {
        "iat": now,
        "exp": now + 600,
        "iss": app_id,
    }
    jwt_token = jwt.encode(payload, private_key, algorithm="RS256")

    url = f"https://api.github.com/app/installations/{installation_id}/access_tokens"
    headers = {
        "Authorization": f"Bearer {jwt_token}",
        "Accept": "application/vnd.github+json",
    }

    resp = requests.post(url, headers=headers, timeout=30)
    resp.raise_for_status()
    print(resp.json()["token"])


if __name__ == "__main__":
    main()
