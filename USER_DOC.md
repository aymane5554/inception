# User Documentation

## Overview

This document is for end-users who want to run and interact with the WordPress stack without dealing with the underlying Docker configuration or development setup.

## Services Provided

The stack includes three services that work together:

### 1. **MariaDB** (Database)
- Provides persistent data storage for WordPress
- Runs in the background on port 3306 (internal only, not exposed to the host)
- Automatically initialized on first run with your configured database and user

### 2. **WordPress** (Application)
- The WordPress application with PHP-FPM
- Handles all website content, pages, posts, and plugins
- Runs in the background and communicates with MariaDB

### 3. **Nginx** (Web Server)
- Reverse proxy and web server that handles HTTP/HTTPS requests
- Provides secure HTTPS access to your WordPress site
- Exposed on port 443 (HTTPS only)
- Routes requests to the WordPress application

## Getting Started

### Prerequisites

- Docker and Docker Compose installed on your system
- The project folder with all configuration files

### Configuration

Before starting the stack for the first time, review the configuration file at `srcs/.env`. This file contains all the settings you might want to customize:

```
DOMAIN_NAME           - Your website domain (e.g., example.com)
MYSQL_ROOT_PASSWORD   - Root password for MariaDB
MYSQL_DATABASE        - Database name for WordPress
MYSQL_USER            - Database user for WordPress
MYSQL_PASSWORD        - Database password
WP_URL                - WordPress URL
WP_TITLE              - Website title
WP_ADMIN_USER         - WordPress admin username
WP_ADMIN_PASSWORD     - WordPress admin password
WP_ADMIN_EMAIL        - WordPress admin email
WP_USER               - Regular WordPress user (additional user)
WP_PASSWORD           - Regular WordPress user password
WP_EMAIL              - Regular WordPress user email
```

## Starting and Stopping the Project

### Start the Stack

To start all services (database, WordPress, and web server), run from the project root:

```bash
make
```

This command will:
- Build Docker images if needed
- Create containers for all three services
- Initialize the database on first run
- Start all services in the background
- Setup persistent data directories

The first start may take a minute as everything is initialized. Subsequent starts are faster.

### Stop the Stack

To stop all running services while preserving data:

```bash
make down
```

This safely shuts down all containers while keeping your data intact. You can start them again later with `make`.

### Restart the Stack

To stop and restart everything fresh:

```bash
make re
```

### Clean Up

To remove Docker resources after stopping:

```bash
make clean
```

To remove everything including persistent data (databases and files):

```bash
make fclean
```

⚠️ **Warning**: `make fclean` will delete all your website content and database. Use only if you want a complete reset.

## Accessing the Website

### WordPress Website

Once the stack is running, access your WordPress site at:

```
https://your-domain-name
```

Replace `your-domain-name` with the value you set in `DOMAIN_NAME` in the `.env` file.

**Note**: The site uses a self-signed HTTPS certificate, so your browser may show a security warning on first access. This is normal and expected. You can safely proceed by clicking "Advanced" or "Continue" (depending on your browser).

### WordPress Admin Panel

To manage your website, access the WordPress admin panel at:

```
https://your-domain-name/wp-admin
```

Log in using the admin credentials:
- **Username**: Value of `WP_ADMIN_USER` from `.env`
- **Password**: Value of `WP_ADMIN_PASSWORD` from `.env`

From the admin panel, you can:
- Create and edit posts and pages
- Manage themes and plugins
- Configure site settings
- Create additional users

## Locating and Managing Credentials

### Where Credentials Are Stored

All sensitive credentials are stored in the `srcs/.env` file at the project root. This file is read by the Docker containers when they start.

### Credentials Checklist

The following credentials are configured in the `.env` file:

| Credential | Used By | Where to Find |
|-----------|---------|---------------|
| Database Root Password | MariaDB Admin | `MYSQL_ROOT_PASSWORD` |
| Database User Password | WordPress ↔ MariaDB | `MYSQL_PASSWORD` |
| Admin Username | WordPress Admin Panel | `WP_ADMIN_USER` |
| Admin Password | WordPress Admin Panel | `WP_ADMIN_PASSWORD` |
| Regular User Password | WordPress User Panel | `WP_PASSWORD` |

### Changing Credentials

To change any credential:

1. Stop the stack: `make down`
2. Edit `srcs/.env` with your new values
3. Remove all data to reset the database: `make fclean`
4. Start the stack again: `make` (this will initialize with new credentials)

⚠️ **Important**: Changing credentials in the `.env` file after the stack is running requires a full database reset (`make fclean`) for the changes to take effect.

### Accessing the Database Directly (Advanced)

If you need direct database access, you can connect using:
- **Host**: `mariadb` (from within containers) or Docker network
- **Port**: `3306` (internal only)
- **Username**: Value of `MYSQL_USER` from `.env`
- **Password**: Value of `MYSQL_PASSWORD` from `.env`
- **Database**: Value of `MYSQL_DATABASE` from `.env`

Or use the root account with `MYSQL_ROOT_PASSWORD` for administrative access.

## Checking Service Status

### View Running Containers

To see if all services are running:

```bash
docker ps
```

You should see three containers:
- `mariadb` (MariaDB database)
- `wordpress` (WordPress application)
- `nginx` (Web server)

All should have status `Up` if running correctly.

### View Container Logs

To see what a service is doing or troubleshoot issues:

```bash
docker logs mariadb      # Database logs
docker logs wordpress    # WordPress logs
docker logs nginx        # Web server logs
```

Add `-f` to follow logs in real-time (exit with Ctrl+C):

```bash
docker logs -f nginx
```

### Common Issues and Solutions

**Website not accessible**
- Ensure the stack is running: `docker ps`
- Check if port 443 is available: `lsof -i :443`
- Verify the domain name matches your `.env` configuration
- Check web server logs: `docker logs nginx`

**Cannot log in to WordPress**
- Verify you're using credentials from the `.env` file
- Check WordPress logs: `docker logs wordpress`
- Ensure MariaDB is running: `docker logs mariadb`

**Database connection error**
- Verify MariaDB is running: `docker ps | grep mariadb`
- Check database logs: `docker logs mariadb`
- Ensure database credentials in `.env` are correct
- Try resetting the stack: `make fclean` then `make`

**Changes not appearing on the website**
- Clear your browser cache (Ctrl+Shift+Delete or Cmd+Shift+Delete)
- Check WordPress logs: `docker logs wordpress`
- Restart services: `make down` then `make`

## Data Persistence

Your website data (database files and WordPress files) is stored in persistent volumes on your host system, typically in:

```
/home/your-username/data/mariadb/    (database files)
/home/your-username/data/wordpress/  (WordPress files, themes, plugins)
```

This means:
- Data survives container restarts (when you run `make down` then `make` again)
- Data is only removed when you run `make fclean`
- Regular backups of these directories are recommended for safety

## Performance Tips

- For optimal performance, ensure Docker has sufficient CPU and memory allocated
- If the site is slow, check container resource usage: `docker stats`
- Monitor database performance in WordPress admin panel

## Troubleshooting

### Stack won't start

1. Check if Docker is running: `docker info`
2. Check for port conflicts: `sudo lsof -i :443`
3. Verify file permissions on data directories
4. Review Docker logs: `docker logs mariadb`

### Site is slow or unresponsive

1. Check service status: `docker ps`
2. Monitor resource usage: `docker stats`
3. Restart the stack: `make down` && `make`
4. Check available disk space for data persistence

### Lost connection or corrupted database

1. Stop the stack: `make down`
2. Try restarting: `make`
3. If issues persist, reset and reinitialize: `make fclean` && `make`

## Next Steps

- Visit the WordPress admin panel to customize your site
- Install themes and plugins from WordPress dashboard
- Create pages and posts for your content
- Configure site settings (title, tagline, etc.)
- Set up permalinks and other WordPress preferences

For technical questions about Docker or advanced configuration, refer to the [DEV_DOC.md](DEV_DOC.md).