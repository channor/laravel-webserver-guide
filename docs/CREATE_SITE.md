# Create a site

This guide will
- Create a dedicated deploy user (no sudo)
- Create the (release-based) directory structure for the site
- Create an SSH key (deploy key) for GitHub and add it to the repository
- Clone the Laravel repository
- Install and configure the app (env, permissions, storage, cache)
- Configure the database and run migrations
- Set up Laravel Scheduler (cron) and queues (Supervisor)
- Point DNS to the server
- Issue a TLS certificate (Certbot) and ensure renewal is enabled
- Configure NGINX server block for the site

## 1. Setup user + directories + ssh

Run the [Setup Server Site script](installers/setup_server_site.sh)

```bash
curl -fsSL -L "https://github.com/channor/laravel-webserver-guide/raw/refs/heads/main/installers/setup_server_site.sh" -o /tmp/setup_server_site.sh
sudo bash /tmp/setup_server_site.sh
rm -f /tmp/setup_server_site.sh
```

