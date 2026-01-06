#!/usr/bin/env bash
set -euo pipefail

# installers/github_deploy_key.sh
#
# Usage (run as the deploy user):
#   DOMAIN="example.com" ./github_deploy_key.sh
#
# Optional:
#   KEY_PATH="$HOME/.ssh/id_ed25519" DOMAIN="example.com" ./github_deploy_key.sh
#   FORCE=1 DOMAIN="example.com" ./github_deploy_key.sh

: "${DOMAIN:?DOMAIN is required (e.g. DOMAIN=example.com)}"

KEY_PATH="${KEY_PATH:-$HOME/.ssh/id_ed25519}"
FORCE="${FORCE:-0}"

# Make sure ~/.ssh exists with correct perms
install -d -m 700 "$HOME/.ssh"

# Generate key if missing (or if FORCE=1)
if [[ -f "$KEY_PATH" && "$FORCE" != "1" ]]; then
  echo "SSH key already exists at $KEY_PATH (skipping)."
else
  if [[ "$FORCE" == "1" ]]; then
    rm -f "$KEY_PATH" "$KEY_PATH.pub"
  fi

  ssh-keygen -t ed25519 -C "${DOMAIN} deploy key" -f "$KEY_PATH" -N "" -q
  chmod 600 "$KEY_PATH"
  chmod 644 "$KEY_PATH.pub"
  echo "Created SSH key at $KEY_PATH"
fi

# Avoid interactive prompt on first GitHub connection
touch "$HOME/.ssh/known_hosts"
chmod 644 "$HOME/.ssh/known_hosts"
ssh-keyscan -H github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true

echo
echo "----- GitHub Deploy Key (add this to your repo) -----"
cat "$KEY_PATH.pub"
echo "-----------------------------------------------------"
echo
