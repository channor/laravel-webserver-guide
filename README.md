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

Example config file to place `/etc/fail2ban/jail.local`:

`sudo nano /etc/fail2ban/jail.local`

```
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
```

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
systemctl status nginx --no-pager
curl -I http://localhost
```