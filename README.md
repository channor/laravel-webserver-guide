# Laravel Webserver Guide

> **USE GUIDE AT YOUR OWN RISK**

A simple guide with templates to setup and configure production ready Ubuntu Server 24.04 to deploy Laravel apps.

## Overview

## Steps to setup server

### SSH into the instance

```bash
ssh -i "path-to-key.pem" ubuntu@host
```

### 1. OS updates and upgrade

```bash
sudo apt update -y
sudo apt upgrade -y
sudo apt autoremove -y
```

Recommended after (you will need to SSH back in to the instance):

`sudo reboot`

### 2. Install base packages

These are some common used packages that will be needed if this guide is followed throughout.

```bash
sudo apt install -y software-properties-common curl wget nano \
  zip unzip openssl expect ca-certificates gnupg lsb-release jq bc python3-pip
```

### 3. Install Fail2Ban

```bash
sudo apt install -y fail2ban
```

Now you may configure jail:

**1. Open jail.local and paste your own config or use example in [example-configs/jail.local](example-configs/jail.local)**
```bash
sudo nano /etc/fail2ban/jail.local
```

**OR**

**2. Copy example directly**

```bash
curl -fsSL -L "https://github.com/channor/laravel-webserver-guide/raw/refs/heads/main/example-configs/jail.local" \
  | sudo tee /etc/fail2ban/jail.local > /dev/null
```

Then enable and start service:

```bash
sudo systemctl enable --now fail2ban
```

Verify:

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

### 4. Configure firewall

UFW is usually pre-installed on AWS.

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose
```

> AWS Security Group rules still apply even if UFW is open

### 5. Install NGINX

```bash
sudo apt install -y nginx
sudo systemctl enable --now nginx
```

Verify it is running:

```bash
sudo systemctl status nginx --no-pager
curl -I http://localhost
```

Verify config and show version:

```bash
sudo nginx -t
nginx -v
```

**Optional:**

```bash
sudo systemctl edit nginx
```

Paste the following after `### Anything between here and the comment below will become the contents of the drop-in file`

```text
[Service]
LimitNOFILE=65535
```

Then reload, restart and show/verify the property:

```bash
sudo systemctl daemon-reload
sudo systemctl restart nginx
sudo systemctl show nginx --property=LimitNOFILE
```

Uncomment `# server_tokens off;` or add `server_tokens off;` inside `http { ... }` block:

```bash
sudo nano /etc/nginx/nginx.conf
```

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 6. Install PHP

> PHP 8.3 is default version on Ubuntu 24.04. Other versions typically require a third-party repo (e.g. Sury PPA).

```bash
sudo apt install -y php8.3-fpm php8.3-common php8.3-cli php8.3-curl \
  php8.3-bcmath php8.3-mbstring php8.3-mysql php8.3-zip \
  php8.3-xml php8.3-soap php8.3-gd php8.3-imagick php8.3-intl \
  php8.3-opcache

sudo systemctl enable --now php8.3-fpm
php -v
sudo systemctl status php8.3-fpm --no-pager
```

Other extensions you might want:

```text
php8.3-sqlite3
php8.3-pgsql
php8.3-redis
php8.3-memcached
```

#### Optional config:

Copy [example-configs/99-laravel.ini](example-configs/99-laravel.ini):

```bash
curl -fsSL -L "https://github.com/channor/laravel-webserver-guide/raw/refs/heads/main/example-configs/99-laravel.ini" \
  | sudo tee /etc/php/8.3/fpm/conf.d/99-laravel.ini > /dev/null
```

Edit the copied config file and uncomment `# expose_php = Off` and/or `# cgi.fix_pathinfo = 0` if preferred:

```bash
sudo nano /etc/php/8.3/fpm/conf.d/99-laravel.ini
```

Configure OPcache by editing (or creating) `99-opcache.ini`:

*Do not edit 10-opcache.ini to avoid overwrite or conflicts on update.*

```bash
curl -fsSL -L "https://github.com/channor/laravel-webserver-guide/raw/refs/heads/main/example-configs/99-opcache.ini" \
  | sudo tee /etc/php/8.3/fpm/conf.d/99-opcache.ini > /dev/null
```

to copy [example-configs/99-opcache.ini](example-configs/99-opcache.ini) to `/etc/php/8.3/fpm/conf.d/99-opcache.ini`

```bash
sudo systemctl reload php8.3-fpm
```

For other PHP versions, see [Install PHP](docs/INSTALL_PHP.md).

### 7. Install composer

The following uses [installers/composer.sh](installers/composer.sh), verifies and installs composer.

```bash
curl -fsSL -L "https://github.com/channor/laravel-webserver-guide/raw/refs/heads/main/installers/composer.sh" -o /tmp/composer.sh
sudo bash /tmp/composer.sh
rm -f /tmp/composer.sh
```