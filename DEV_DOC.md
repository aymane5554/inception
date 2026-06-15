# Developer Documentation

This document provides developers with comprehensive instructions for setting up, building, and managing the Inception project.

## Table of Contents
1. [Environment Setup](#environment-setup)
2. [Building the Project](#building-the-project)
3. [Container Management](#container-management)
4. [Data Persistence](#data-persistence)
5. [Debugging](#debugging)

## Environment Setup

### Prerequisites
- Set up the environment from scratch (prerequisites, configuration files, secrets).

#### Step 1: Install Dependencies
```bash
# Ubuntu/Debian
sudo apt-get install docker.io docker-compose make

# macOS
brew install docker docker-compose make
```

#### Step 2: Create Configuration Files
Create a `.env` file in the project root:
```bash
# Database Configuration
DB_NAME=inception_db
DB_USER=inception_user
DB_PASSWORD=your_secure_password
DB_ROOT_PASSWORD=your_root_password

# WordPress Configuration
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=admin_password
WP_ADMIN_EMAIL=admin@example.com

# Domain
DOMAIN_NAME=localhost
```

#### Step 3: Initialize Secrets
```bash
mkdir -p secrets
echo -n "database_password" > secrets/db_password.txt
echo -n "wordpress_password" > secrets/wp_password.txt
```

## Building the Project

### Build and Launch the Project

#### Using Makefile (Recommended)
```bash
# Build Docker images
make build

# Start all services
make up

# View build output
make logs
```

#### Manual Docker Compose
```bash
# Build images
docker-compose build

# Start services in background
docker-compose up -d

# View logs
docker-compose logs -f
```

### Build Process Details

The Makefile orchestrates the following steps:
1. **Validate Configuration**: Check for required .env files and directories
2. **Build Images**: Each service builds its Docker image from specified Dockerfiles
3. **Create Volumes**: Named volumes for persistent data are created
4. **Start Containers**: Services start in dependency order
5. **Verify Services**: Health checks ensure all containers are running

### Troubleshooting Build Issues

**Port Already in Use:**
```bash
# Find process using port 443
sudo lsof -i :443
# Free the port or change mapping in docker-compose.yml
```

**Insufficient Disk Space:**
```bash
# Clean up unused Docker objects
docker system prune -a
```

## Container Management

### Useful Commands

```bash
# View running containers
docker-compose ps
# or
make ps

# View logs
docker-compose logs [service_name]
docker-compose logs -f  # Follow logs in real-time

# Execute commands in container
docker-compose exec [service_name] [command]
# Example: Access MariaDB
docker-compose exec mariadb mysql -u root -p

# Stop services
docker-compose stop

# Restart services
docker-compose restart [service_name]

# Remove containers and volumes
docker-compose down -v
```

### Service-Specific Commands

**Nginx:**
```bash
# Check Nginx configuration
docker-compose exec nginx nginx -t

# View Nginx logs
docker-compose exec nginx tail -f /var/log/nginx/error.log
```

**MariaDB:**
```bash
# Access database
docker-compose exec mariadb mysql -u root -p

# Backup database
docker-compose exec mariadb mysqldump -u root -p > backup.sql
```

**WordPress:**
```bash
# Access WordPress container
docker-compose exec wordpress bash

# View WordPress logs
docker-compose exec wordpress tail -f /var/log/wordpress/error.log
```

## Data Persistence

### Identify Where Project Data Is Stored

Data is persisted in named Docker volumes:

```bash
# List all volumes
docker volume ls

# Inspect a volume
docker volume inspect inception_db_data
```

### Volume Locations

- **Database Data**: `inception_db_data` → `/var/lib/mysql/`
- **WordPress Files**: `inception_wp_data` → `/var/www/html/`
- **Nginx Config**: `inception_nginx_conf` → `/etc/nginx/`

### Ensuring Data Persists

Volumes are defined in `docker-compose.yml`:
```yaml
volumes:
  db_data:
    driver: local
  wp_data:
    driver: local
```

Services mount these volumes:
```yaml
services:
  mariadb:
    volumes:
      - db_data:/var/lib/mysql
```

### Backup and Restore

**Backup Database:**
```bash
docker-compose exec mariadb mysqldump -u root -p${DB_ROOT_PASSWORD} \
  --all-databases > backup.sql
```

**Restore Database:**
```bash
docker-compose exec -T mariadb mysql -u root -p${DB_ROOT_PASSWORD} < backup.sql
```

**Backup WordPress Files:**
```bash
docker run --rm -v inception_wp_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/wp_backup.tar.gz -C /data .
```

## Debugging

### Common Issues and Solutions

**Containers Exit Immediately:**
```bash
# Check logs
docker-compose logs [service_name]

# Verify configuration files exist
ls -la config/
```

**Database Connection Refused:**
```bash
# Verify MariaDB is running
docker-compose ps mariadb

# Check database logs
docker-compose logs mariadb

# Verify environment variables
docker-compose exec mariadb env | grep DB_
```

**Nginx Returns 502 Bad Gateway:**
```bash
# Verify WordPress container is running
docker-compose ps wordpress

# Check Nginx logs
docker-compose logs nginx

# Test connection from Nginx
docker-compose exec nginx curl http://wordpress:9000
```

### Useful Debugging Commands

```bash
# Get full container details
docker inspect [container_id]

# Monitor resource usage
docker stats

# Execute shell in container
docker-compose exec [service] sh
docker-compose exec [service] bash

# View network connections
docker network ls
docker network inspect inception_default
```

### Development Workflow

1. Make code changes in your local repository
2. Rebuild affected images: `docker-compose build [service]`
3. Restart services: `docker-compose restart [service]`
4. Verify changes: `docker-compose logs -f [service]`
5. Test functionality through the web interface or API

### Performance Optimization

```bash
# Use build cache effectively
docker-compose build --no-cache  # Force rebuild

# Monitor container resource usage
docker stats --no-stream

# Optimize image sizes
docker image ls --format "{{.Repository}}:{{.Tag}}\t{{.Size}}"
```
