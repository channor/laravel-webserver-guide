#!/usr/bin/env bash
# installers/create_mysql_db_user.sh
# Run:
#   sudo DB_NAME=example_xxxxx TYPE=OWNER SITE_USER=example bash installers/create_mysql_db_user.sh
#   sudo DB_NAME=example_xxxxx TYPE=APP   SITE_USER=example bash installers/create_mysql_db_user.sh
# Optional override:
#   sudo DB_USER=custom_user DB_NAME=... TYPE=APP SITE_USER=... bash installers/create_mysql_db_user.sh

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run with sudo/root." >&2
  exit 1
fi

command -v mysql >/dev/null 2>&1 || { echo "mysql not found (install mysql-server)"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl not found"; exit 1; }

: "${SITE_USER:?SITE_USER is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${TYPE:?TYPE is required (OWNER or APP)}"

TYPE_UPPER="$(echo "$TYPE" | tr '[:lower:]' '[:upper:]')"
if [[ "$TYPE_UPPER" != "OWNER" && "$TYPE_UPPER" != "APP" ]]; then
  echo "TYPE must be OWNER or APP" >&2
  exit 1
fi

DEFAULT_USER="${SITE_USER}_db_${TYPE_UPPER,,}"  # e.g. example_db_owner / example_db_app
DB_USER="${DB_USER:-$DEFAULT_USER}"

# Strong random password (avoid quotes/backticks to simplify SQL embedding)
DB_PASS="$(openssl rand -base64 36 | tr -d '\n' | tr -d "'\"\\\`" | head -c 32)"

# Validate
if [[ ! "$DB_USER" =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Invalid DB_USER '$DB_USER' (use only letters, digits, underscore)" >&2
  exit 1
fi
if [[ ! "$DB_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Invalid DB_NAME '$DB_NAME' (use only letters, digits, underscore)" >&2
  exit 1
fi

mysql <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
  IDENTIFIED WITH caching_sha2_password BY '${DB_PASS}';
EOF

if [[ "$TYPE_UPPER" == "OWNER" ]]; then
  mysql <<EOF
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
else
  # APP user: runtime privileges (no CREATE/DROP/ALTER)
  mysql <<EOF
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE
ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
fi

echo
echo "DB user created/updated:"
echo "  DB_NAME=$DB_NAME"
echo "  DB_USER=$DB_USER"
echo "  DB_PASS=$DB_PASS"
echo "  HOST=127.0.0.1"
echo
echo "Store this securely (it will not be saved anywhere)."
echo
