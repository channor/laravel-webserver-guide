#!/bin/bash

# installers/composer.sh

set -euo pipefail

EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"

# Verify installer
if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
  >&2 echo "ERROR: Invalid Composer installer checksum"
  rm -f /tmp/composer-setup.php
  exit 1
fi

# Install globally
php /tmp/composer-setup.php --no-interaction --install-dir=/usr/local/bin --filename=composer
rm -f /tmp/composer-setup.php

# Verify
composer --version
