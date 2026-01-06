#!/usr/bin/env bash
# installers/deploy_app.sh

set -euo pipefail

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Please run as root (use sudo)." >&2
    exit 1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

require_root
require_cmd git
require_cmd composer
require_cmd php

read -r -p "Site user (example): " SITE_USER
CONFIG="/home/${SITE_USER}/.laravel-site.env"
[[ -f "$CONFIG" ]] || { echo "Config not found: $CONFIG (run setup_server_site.sh first)" >&2; exit 1; }

# shellcheck disable=SC1090
source "$CONFIG"

echo "==> First release for ${DOMAIN}"
RELEASE="$(date +%Y%m%d_%H%M%S)"
RELEASE_DIR="${SITE_ROOT}/releases/${RELEASE}"

echo "==> Cloning (${BRANCH}) into ${RELEASE_DIR}"
sudo -iu "$SITE_USER" bash -lc "
set -euo pipefail
mkdir -p '$RELEASE_DIR'
git clone --depth=1 --branch '$BRANCH' '$REPO_SSH' '$RELEASE_DIR'
"

echo "==> Linking shared .env + storage"
sudo -iu "$SITE_USER" bash -lc "
set -euo pipefail
cd '$RELEASE_DIR'
ln -sfn '$SITE_ROOT/shared/.env' .env
rm -rf storage
ln -sfn '$SITE_ROOT/shared/storage' storage
mkdir -p bootstrap/cache
chmod -R ug+rwX bootstrap/cache '$SITE_ROOT/shared/storage'
"

# If shared .env is empty and .env.example exists, offer to copy
if [[ ! -s "${SITE_ROOT}/shared/.env" ]]; then
  if sudo -iu "$SITE_USER" test -f "${RELEASE_DIR}/.env.example"; then
    read -r -p "shared/.env is empty. Copy .env.example to shared/.env? [Y/n]: " COPY_ENV
    COPY_ENV="${COPY_ENV:-Y}"
    if [[ ! "$COPY_ENV" =~ ^[Nn]$ ]]; then
      sudo -iu "$SITE_USER" bash -lc "cp '${RELEASE_DIR}/.env.example' '${SITE_ROOT}/shared/.env'"
      echo "==> Copied. Please edit shared/.env now."
      sudo -iu "$SITE_USER" bash -lc "nano '${SITE_ROOT}/shared/.env'"
    fi
  else
    echo "NOTE: shared/.env is empty and .env.example not found. Create/edit: ${SITE_ROOT}/shared/.env"
  fi
fi

echo "==> Composer install (no-dev)"
sudo -iu "$SITE_USER" bash -lc "
set -euo pipefail
cd '$RELEASE_DIR'
composer install --no-interaction --no-dev --optimize-autoloader
"

# Optional artisan steps
read -r -p "Run artisan key:generate (requires working .env)? [y/N]: " DO_KEY
DO_KEY="${DO_KEY:-N}"
if [[ "$DO_KEY" =~ ^[Yy]$ ]]; then
  sudo -iu "$SITE_USER" bash -lc "
  set -euo pipefail
  cd '$RELEASE_DIR'
  php artisan key:generate --force
  "
fi

read -r -p "Run artisan cache commands (config/route/view)? [Y/n]: " DO_CACHE
DO_CACHE="${DO_CACHE:-Y}"
if [[ ! "$DO_CACHE" =~ ^[Nn]$ ]]; then
  sudo -iu "$SITE_USER" bash -lc "
  set -euo pipefail
  cd '$RELEASE_DIR'
  php artisan config:cache || true
  php artisan route:cache || true
  php artisan view:cache  || true
  "
fi

echo "==> Activating release (current -> ${RELEASE})"
ln -sfn "$RELEASE_DIR" "${SITE_ROOT}/current"

echo "==> Reloading PHP-FPM: ${PHP_FPM_SERVICE}"
systemctl reload "$PHP_FPM_SERVICE"

echo
echo "==> Done."
echo "Current points to: ${SITE_ROOT}/current"
echo "Next: sudo bash installers/setup_domain_and_https.sh"
