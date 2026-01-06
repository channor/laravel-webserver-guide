# Install PHP

Installing PHP is covered in [README.md](/README.md). If you need other versions, it might be covered here.

> THE FOLLOWING HAS NOT BEEN VERIFIED/TESTED

## PHP 8.2

1. [Add PPA ondrej/php](#add-ppa-ondrejphp)
2. Install PHP 8.2
   
    ```bash
   sudo apt install -y php8.2-fpm php8.2-common php8.2-cli php8.2-curl \
    php8.2-bcmath php8.2-mbstring php8.2-mysql php8.2-zip \
    php8.2-xml php8.2-soap php8.2-gd php8.2-imagick php8.2-intl \
    php8.2-opcache
    ```

## Add PPA ondrej/php

To install other version than 8.3, you need third-party package.

```bash
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
```

**Check the packages exists:**

Change version (and extension) if wanted.

```bash
apt-cache policy php8.2-fpm
```