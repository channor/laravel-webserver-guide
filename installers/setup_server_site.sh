#!/usr/bin/env bash
#

#################################
# script: installers/setup_server_site.sh
#
# Setup
# - Server user dedicated for one site/app
# - Create directory structure and set permissions
# - Create .env placeholder
# - Create SSH deploy key
# - Setup a mysql database
# - Create a database owner user and a random strong password (for migration)
# - Create a database user for the app

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
require_cmd adduser
require_cmd usermod
require_cmd ssh-keygen
require_cmd ssh-keyscan
require_cmd mysql
require_cmd openssl

echo "==> Site setup (this will create user + dirs + deploy key, then store config)."
echo

read -r -p "Domain (example.com): " DOMAIN
[[ -n "${DOMAIN}" ]] || { echo "Domain is required." >&2; exit 1; }

read -r -p "Site user (one per site) (example): " SITE_USER
[[ -n "${SITE_USER}" ]] || { echo "Site user is required." >&2; exit 1; }

read -r -p "Repo SSH (git@github.com:ORG/REPO.git): " REPO_SSH
[[ -n "${REPO_SSH}" ]] || { echo "Repo SSH is required." >&2; exit 1; }

read -r -p "Default branch [main]: " BRANCH
BRANCH="${BRANCH:-main}"

read -r -p "PHP-FPM socket [/run/php/php8.3-fpm.sock]: " PHP_FPM_SOCK
PHP_FPM_SOCK="${PHP_FPM_SOCK:-/run/php/php8.3-fpm.sock}"

read -r -p "PHP-FPM systemd service [php8.3-fpm]: " PHP_FPM_SERVICE
PHP_FPM_SERVICE="${PHP_FPM_SERVICE:-php8.3-fpm}"

read -r -p "Include www.${DOMAIN} in NGINX/certbot? [Y/n]: " WITH_WWW
WITH_WWW="${WITH_WWW:-Y}"
WITH_WWW=$([[ "$WITH_WWW" =~ ^[Nn]$ ]] && echo "0" || echo "1")

read -r -p "Certbot email (optional, Enter to be prompted later): " CERTBOT_EMAIL

read -r -p "NGINX client_max_body_size [50M]: " CLIENT_MAX_BODY_SIZE
CLIENT_MAX_BODY_SIZE="${CLIENT_MAX_BODY_SIZE:-50M}"

SITE_ROOT="/var/www/${DOMAIN}"
CONFIG_PATH="/home/${SITE_USER}/.laravel-site.env"

echo
echo "==> Creating deploy user: ${SITE_USER}"
if id -u "$SITE_USER" >/dev/null 2>&1; then
  echo "User exists, skipping adduser."
else
  adduser --disabled-password --gecos "" "$SITE_USER"
fi
usermod -aG www-data "$SITE_USER"

echo "==> Creating site directories: ${SITE_ROOT}"
mkdir -p "${SITE_ROOT}/"{releases,shared}
mkdir -p "${SITE_ROOT}/shared/storage"

chown -R "${SITE_USER}:www-data" "${SITE_ROOT}"
chmod -R 2755 "${SITE_ROOT}"
chmod -R 2775 "${SITE_ROOT}/shared/storage"

echo "==> Creating shared .env placeholder"
sudo -iu "$SITE_USER" bash -lc "touch '${SITE_ROOT}/shared/.env' && chmod 640 '${SITE_ROOT}/shared/.env'"

echo "==> Creating SSH deploy key for ${SITE_USER}"

curl -fsSL -L "https://github.com/channor/laravel-webserver-guide/raw/refs/heads/main/installers/github_deploy_key.sh" -o /tmp/github_deploy_key.sh
sudo -iu "$SITE_USER" DOMAIN="$DOMAIN" bash /tmp/github_deploy_key.sh
rm -f /tmp/github_deploy_key.sh

echo "==> Add the above key in GitHub as a Deploy Key (read-only is fine)."
read -r -p "Press Enter when you've added the deploy key..."

echo "==> Testing GitHub SSH as ${SITE_USER} (non-fatal)"
sudo -iu "$SITE_USER" bash -lc "ssh -o StrictHostKeyChecking=accept-new -T git@github.com || true"

echo "==> Writing config to ${CONFIG_PATH}"
tmp="$(mktemp)"
{
  printf 'DOMAIN=%q\n' "$DOMAIN"
  printf 'SITE_USER=%q\n' "$SITE_USER"
  printf 'REPO_SSH=%q\n' "$REPO_SSH"
  printf 'BRANCH=%q\n' "$BRANCH"
  printf 'SITE_ROOT=%q\n' "$SITE_ROOT"
  printf 'PHP_FPM_SOCK=%q\n' "$PHP_FPM_SOCK"
  printf 'PHP_FPM_SERVICE=%q\n' "$PHP_FPM_SERVICE"
  printf 'WITH_WWW=%q\n' "$WITH_WWW"
  printf 'CERTBOT_EMAIL=%q\n' "${CERTBOT_EMAIL}"
  printf 'CLIENT_MAX_BODY_SIZE=%q\n' "$CLIENT_MAX_BODY_SIZE"
} > "$tmp"

install -m 600 "$tmp" "$CONFIG_PATH"
chown "$SITE_USER:$SITE_USER" "$CONFIG_PATH"
rm -f "$tmp"

echo "==> Creating database"

curl -fsSL -L "https://github.com/channor/laravel-webserver-guide/raw/refs/heads/main/installers/create_mysql_database.sh" -o /tmp/create_mysql_database.sh

read -r -p "DB name (Enter for auto): " DB_NAME
if [[ -z "${DB_NAME}" ]]; then
  RAND_SUFFIX="$(openssl rand -base64 9 | tr -dc 'a-z0-9' | head -c 8)"
  DB_NAME="${SITE_USER}_${RAND_SUFFIX}"
  echo "Using generated DB name: $DB_NAME"
fi

sudo SITE_USER="$SITE_USER" DB_NAME="$DB_NAME" bash /tmp/create_mysql_database.sh
rm -f /tmp/create_mysql_database.sh

echo "==> Creating database users"
curl -fsSL -L "https://github.com/channor/laravel-webserver-guide/raw/refs/heads/main/installers/create_mysql_db_user.sh" -o /tmp/create_mysql_db_user.sh

echo "==> Creating database owner user"
sudo SITE_USER="$SITE_USER" DB_NAME="$DB_NAME" TYPE="OWNER" bash /tmp/create_mysql_db_user.sh

echo "==> Creating database app user"
sudo SITE_USER="$SITE_USER" DB_NAME="$DB_NAME" TYPE="APP" bash /tmp/create_mysql_db_user.sh

rm -f /tmp/create_mysql_db_user.sh

# Append DB_NAME to config (no creds)
echo "DB_NAME=$(printf %q "$DB_NAME")" >> "$CONFIG_PATH"
chown "$SITE_USER:$SITE_USER" "$CONFIG_PATH"
chmod 600 "$CONFIG_PATH"

echo "Database: $DB_NAME"

echo
echo "==> Done."
echo "Config stored at: ${CONFIG_PATH}"
