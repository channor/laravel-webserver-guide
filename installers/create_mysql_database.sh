#!/usr/bin/env bash
# installers/create_mysql_database.sh
# Run: sudo SITE_USER=example bash installers/create_mysql_database.sh
# Optional: sudo DB_NAME=example_ds8iikd SITE_USER=example bash installers/create_mysql_database.sh

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run with sudo/root." >&2
  exit 1
fi

command -v mysql >/dev/null 2>&1 || { echo "mysql not found (install mysql-server)"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl not found"; exit 1; }

: "${SITE_USER:?SITE_USER is required (e.g. SITE_USER=example)}"

# Generate a short suffix (lowercase letters + digits) to keep names simple
rand_suffix() {
  openssl rand -base64 9 | tr -dc 'a-z0-9' | head -c 8
}

DB_NAME="${DB_NAME:-${SITE_USER}_$(rand_suffix)}"

# Basic name validation (MySQL identifiers: keep it simple)
if [[ ! "$DB_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Invalid DB_NAME '$DB_NAME' (use only letters, digits, underscore)" >&2
  exit 1
fi

mysql <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
EOF

echo
echo "Database created (or already existed): $DB_NAME"
echo
