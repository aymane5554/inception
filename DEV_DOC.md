# Developer Documentation

## Overview

This document provides technical guidance for developers working with the Inception WordPress stack. It covers environment setup, build procedures, container management, and data persistence.

## Prerequisites

### System Requirements

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 1.29 or higher
- **Linux Host**: The project is designed for Linux (Ubuntu, Debian, CentOS, etc.)
- **Disk Space**: At least 5GB free space for containers and data volumes
- **Network**: Port 443 (HTTPS) must be available

### Verify Installation

```bash
docker --version
docker compose version
```

## Environment Configuration

### The `.env` File

The project uses a `.env` file located at `srcs/.env` to manage all environment variables. This file is sourced by Docker Compose and passed to all containers.

#### Required Variables

```
# MariaDB Configuration
MYSQL_ROOT_PASSWORD=your_root_password
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress_user
MYSQL_PASSWORD=wordpress_password

# WordPress Configuration
WP_URL=https://example.com
WP_TITLE=My WordPress Site
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=admin_password
WP_ADMIN_EMAIL=admin@example.com
WP_USER=user
WP_PASSWORD=user_password
WP_EMAIL=user@example.com
```

#### Creating/Updating `.env`

```bash
# Navigate to the project root
cd /path/to/inception

# Edit or create .env
nano srcs/.env
```

**Important**: Keep sensitive credentials secure. Never commit `.env` to version control.

## Build and Launch

### Makefile Commands

The project provides a Makefile with convenience targets for building and managing the stack.

#### Target: `make` (or `make all`)

Builds and starts all services:

```bash
make
```

**What it does:**
1. Creates necessary data directories (`/home/aymane/data/mariadb` and `/home/aymane/data/wordpress`)
2. Builds Docker images for MariaDB, WordPress, and Nginx
3. Creates and starts all containers
4. Initializes the MariaDB database
5. Installs and configures WordPress
6. Starts Nginx with HTTPS

**First Run**: May take 1-3 minutes as images are built and services initialize.

#### Target: `make down`

Stops all running containers:

```bash
make down
```

**What it does:**
- Gracefully stops all containers
- Preserves data volumes (data is NOT deleted)
- Removes network connections

#### Target: `make clean`

Removes stopped containers and unused Docker resources:

```bash
make clean
```

**What it does:**
- Stops all containers (if running)
- Removes stopped containers
- Prunes unused images, networks, and build cache
- Data volumes are preserved

#### Target: `make fclean`

Complete cleanup including data:

```bash
make fclean
```

**⚠️ WARNING**: This command deletes all persistent data!

**What it does:**
- Stops all containers
- Removes containers and images
- **Deletes the entire `/home/aymane/data` directory**
- Removes all volumes

Use only when you want a complete reset of the entire stack.

#### Target: `make re`

Rebuilds everything from scratch:

```bash
make re
```

**What it does:**
- Runs `make fclean`
- Runs `make all`
- Equivalent to a complete reset and rebuild

### Docker Compose Manual Commands

If you need to interact with Docker Compose directly:

```bash
# Start services in background
docker compose -f srcs/docker-compose.yml up -d --build

# Stop services
docker compose -f srcs/docker-compose.yml down

# View running services
docker compose -f srcs/docker-compose.yml ps

# View service logs
docker compose -f srcs/docker-compose.yml logs

# Execute command in container
docker compose -f srcs/docker-compose.yml exec wordpress bash
```

## Container Management

### Service Architecture

The stack consists of three services connected via a bridge network (`inception`):

#### 1. **MariaDB** (Database)
- **Container Name**: `mariadb`
- **Port**: 3306 (internal only, not exposed)
- **Volumes**: `mariadb:/var/lib/mysql`
- **Network**: `inception`
- **Initialization**: Automatic on first run via `init.sh`
- **Restart Policy**: Always

#### 2. **WordPress** (Application)
- **Container Name**: `wordpress`
- **Port**: 9000 (PHP-FPM, internal only)
- **Volumes**: `wordpress:/var/www/wordpress`
- **Network**: `inception`
- **Dependencies**: Requires `mariadb` to be running
- **Initialization**: Automatic on first run via `wp_init.sh`
- **Restart Policy**: Always

#### 3. **Nginx** (Web Server)
- **Container Name**: `nginx`
- **Port**: 443 (HTTPS to host)
- **Volumes**: `wordpress:/var/www/wordpress` (shared with WordPress)
- **Network**: `inception`
- **Dependencies**: Requires `wordpress` to be running
- **TLS**: Self-signed certificates generated automatically
- **Restart Policy**: Always

### Viewing Container Status

```bash
# List all containers
docker ps -a

# Show only running containers
docker ps

# Detailed container information
docker inspect <container_name>
```

### Container Logs

```bash
# View logs for a specific service
docker logs mariadb
docker logs wordpress
docker logs nginx

# Follow logs in real-time (Ctrl+C to exit)
docker logs -f nginx

# Show last 100 lines
docker logs --tail 100 nginx

# Show logs with timestamps
docker logs -t nginx
```

### Executing Commands in Containers

```bash
# Open interactive shell
docker exec -it wordpress bash

# Run single command
docker exec wordpress wp --path=/var/www/wordpress user list

# Run as specific user
docker exec -u www-data wordpress wp --path=/var/www/wordpress plugin list
```

### Resource Usage

```bash
# View real-time resource usage
docker stats

# View resource usage for specific containers
docker stats wordpress nginx mariadb
```

## Volume and Data Management

### Volume Configuration

The `docker-compose.yml` defines two named volumes with bind mounts:

#### `mariadb` Volume

```yaml
volumes:
  mariadb:
    driver_opts:
      type: none
      o: bind 
      device: '/home/aymane/data/mariadb'
```

- **Mount Point in Container**: `/var/lib/mysql`
- **Host Path**: `/home/aymane/data/mariadb`
- **Content**: MariaDB database files

#### `wordpress` Volume

```yaml
volumes:
  wordpress:
    driver_opts:
      type: none
      o: bind 
      device: '/home/aymane/data/wordpress'
```

- **Mount Point in Container**: `/var/www/wordpress`
- **Host Path**: `/home/aymane/data/wordpress`
- **Content**: WordPress application files, themes, plugins, uploads

### Data Persistence Locations

```
/home/aymane/data/
├── mariadb/
│   ├── mysql/
│   ├── performance_schema/
│   └── [other database files]
└── wordpress/
    ├── wp-admin/
    ├── wp-content/
    │   ├── plugins/
    │   ├── themes/
    │   └── uploads/
    ├── wp-includes/
    ├── wp-config.php
    └── [other WordPress files]
```

### Data Backup

Before major changes or regular maintenance, backup your data:

```bash
# Backup MariaDB volume
tar -czf mariadb_backup_$(date +%Y%m%d_%H%M%S).tar.gz /home/aymane/data/mariadb

# Backup WordPress volume
tar -czf wordpress_backup_$(date +%Y%m%d_%H%M%S).tar.gz /home/aymane/data/wordpress

# Backup both
tar -czf inception_backup_$(date +%Y%m%d_%H%M%S).tar.gz /home/aymane/data
```

### Volume Inspection

```bash
# List all volumes
docker volume ls

# Inspect a volume
docker volume inspect inception_mariadb

# Prune unused volumes
docker volume prune
```

## Database Access

### From Within Containers

```bash
# Access MariaDB from WordPress container
docker exec wordpress mysql -h mariadb -u wordpress_user -p wordpress -e "SHOW TABLES;"
```

## Network Architecture

The stack uses a custom bridge network (`inception`) for service-to-service communication:

```
┌─────────────────────────────────────────────────────────┐
│                    Host Network                         │
│                    Port 443 (HTTPS)                     │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ Host:Container
                       │ 443:443
                       │
                  ┌────▼──────────┐
                  │    Nginx      │
                  │ (Port 443)    │
                  └────┬──────────┘
                       │
        ┌──────────────────────────────────────┐
        │     Bridge Network: inception        │
        │  (Internal container communication)  │
        │                                      │
    ┌───┴────────┐                    ┌────────┴────┐
    │ WordPress  │ ◄────────────────► │   MariaDB   │
    │ (Port 9000)│      (Port 3306)   │  (Internal) │
    └────────────┘                    └─────────────┘
```
