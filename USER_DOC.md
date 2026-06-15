# User Documentation

This guide helps end-users understand, start, and manage the Inception web infrastructure.

## Table of Contents
1. [Understanding the Stack](#understanding-the-stack)
2. [Getting Started](#getting-started)
3. [Accessing Services](#accessing-services)
4. [Managing Credentials](#managing-credentials)
5. [Service Health](#service-health)
6. [Common Tasks](#common-tasks)

## Understanding the Stack

### What Services Are Provided by the Stack?

The Inception stack provides a complete web infrastructure with the following services:

#### 1. **Web Server (Nginx)**
- Handles incoming HTTP/HTTPS requests
- Acts as a reverse proxy to WordPress
- Serves static files efficiently
- Provides SSL/TLS encryption for secure communication
- Listens on ports 80 (HTTP) and 443 (HTTPS)

#### 2. **Content Management System (WordPress)**
- Allows you to create, edit, and publish content
- Provides a user-friendly administration interface
- Manages users, posts, pages, and media
- Extensible with plugins and themes
- Runs on port 9000 (internal, accessed through Nginx)

#### 3. **Database (MariaDB)**
- Stores all website content, user data, and configurations
- Runs reliably and securely in an isolated container
- Accessible only from within the Docker network
- Uses encrypted connections for data transmission
- Runs on port 3306 (internal only)

#### 4. **Optional: Cache Layer (Redis)**
- Improves performance by caching frequently accessed data
- Reduces database load
- Accelerates page load times
- Runs on port 6379 (internal only)

### Architecture Benefits

```
User (Internet) → Nginx (443/80) → WordPress → MariaDB
                      ↓
                   SSL/TLS
                   Encryption
```

## Getting Started

### Start the Project

**Using the provided startup script:**
```bash
./start.sh
```

**Or manually:**
```bash
docker-compose up -d
```

Wait 30-60 seconds for services to fully initialize.

### Verify All Services Are Running

```bash
# Check service status
docker-compose ps

# Expected output: All services should show "Up"
```

### Initial WordPress Setup

1. Open your browser and navigate to `https://localhost`
2. If you see an SSL warning, click "Advanced" and proceed
3. Complete the WordPress installation wizard:
   - Select your language
   - Create an admin account
   - Configure site title and tagline
4. Log in to the WordPress dashboard

## Accessing Services

### Website Access

**Public Access:**
- URL: `https://localhost` (or your configured domain)
- This is your public-facing website
- Accessible to all visitors

### Administration Panel

**WordPress Admin:**
- URL: `https://localhost/wp-admin`
- Or use the admin link from the dashboard
- Requires valid WordPress credentials

**Access Admin Features:**
1. Click "Dashboard" from the homepage
2. Log in with your admin credentials
3. From here you can:
   - Create and edit pages
   - Manage users and roles
   - Install plugins and themes
   - Configure site settings

### Direct Database Access (Advanced Users)

```bash
# Access MariaDB directly
docker-compose exec mariadb mysql -u root -p

# When prompted, enter the database root password
# Run SQL queries as needed
```

## Managing Credentials

### Where Credentials Are Stored

Credentials are managed in the `.env` file (not included in version control for security):

```
DB_NAME=inception_db
DB_USER=inception_user
DB_PASSWORD=[database_password]
DB_ROOT_PASSWORD=[root_password]
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=[admin_password]
WP_ADMIN_EMAIL=admin@example.com
```

### Changing Passwords

**WordPress Admin Password:**
1. Log in to WordPress admin panel
2. Go to Users → Your Profile
3. Scroll to "Account Management"
4. Click "Generate Password"
5. Update password and save

**Database Password:**
```bash
# Access the database
docker-compose exec mariadb mysql -u root -p

# Run the following SQL command
ALTER USER 'inception_user'@'%' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;

# Update .env file with new password
# Restart WordPress container for changes to take effect
```

### Security Best Practices

- **Never share credentials** via email or version control
- **Use strong passwords** (minimum 16 characters, mix of uppercase, lowercase, numbers, symbols)
- **Regularly update** WordPress, plugins, and themes
- **Create user backups** of important data
- **Restrict admin access** to trusted users only
- **Enable SSL/TLS** for all connections (already enabled by default)

## Service Health

### Check That Services Are Running Correctly

**Quick Status Check:**
```bash
docker-compose ps
```

Expected output:
```
NAME                   STATUS
inception-nginx        Up (healthy)
inception-wordpress    Up
inception-mariadb      Up (healthy)
```

### Health Status Indicators

- **Green/Healthy**: Service is running normally
- **Unhealthy**: Service has issues; check logs
- **Exited**: Service crashed; check logs and error messages

### Checking Service Logs

**View Recent Logs:**
```bash
docker-compose logs --tail=50 [service_name]
```

**Follow Live Logs:**
```bash
docker-compose logs -f [service_name]
```

**Service-Specific Checks:**

**Nginx Health:**
- Visit `https://localhost` in your browser
- You should see your website
- No error pages (5xx errors indicate problems)

**WordPress Health:**
- Check the admin panel at `https://localhost/wp-admin`
- You should be able to log in
- Dashboard should load without errors

**Database Health:**
```bash
docker-compose exec mariadb mysql -u root -p -e "SELECT 1;"
```
Should return: `1`

### Interpreting Common Error Messages

**"Connection Refused"**
- Database or WordPress service may be down
- Run: `docker-compose restart`

**"502 Bad Gateway"**
- Nginx cannot reach WordPress
- Check: `docker-compose logs wordpress`

**"Timeout"**
- Service is too slow or unresponsive
- Increase Docker resource allocation in Settings

**"SSL Certificate Error"**
- Certificate may be self-signed
- This is normal for local development
- Accept the certificate in your browser

## Common Tasks

### Restart a Service

```bash
# Restart a specific service
docker-compose restart [service_name]

# Example: Restart WordPress
docker-compose restart wordpress
```

### View Website Statistics

```bash
# Monitor real-time resource usage
docker stats

# View disk usage
du -sh volumes/
```

### Backup Your Site

**Quick Backup:**
```bash
# Backup database
docker-compose exec mariadb mysqldump -u root -p --all-databases > backup_$(date +%Y%m%d).sql

# Backup WordPress files
tar -czf wordpress_backup_$(date +%Y%m%d).tar.gz volumes/wordpress/
```

### Update WordPress

**Automatic Update:**
1. Log in to WordPress admin
2. Go to Dashboard → Updates
3. Click "Update" next to WordPress version
4. Click "Update Now"

**Manual Restart (if needed):**
```bash
docker-compose restart wordpress
```

### Stop the Project

```bash
# Stop all services (data is preserved)
docker-compose stop

# Or use the provided script
./stop.sh
```

### Fully Clean Up (Remove Everything)

**WARNING: This will delete all data!**

```bash
# Remove containers, networks, and volumes
docker-compose down -v

# This action cannot be undone; ensure you have backups
```

## Troubleshooting

### Website Won't Load

1. Check if containers are running: `docker-compose ps`
2. Check browser console for errors (F12)
3. Verify SSL certificate is accepted
4. Clear browser cache: Ctrl+Shift+Delete
5. Check service logs: `docker-compose logs`

### Can't Log In to Admin

1. Verify you're using the correct username and password
2. Try resetting via database:
   ```bash
   docker-compose exec wordpress wp user list
   docker-compose exec wordpress wp user update [ID] --prompt=user_pass
   ```

### Services Keep Restarting

1. Check logs: `docker-compose logs [service]`
2. Verify .env file is correct
3. Check disk space: `df -h`
4. Verify Docker has sufficient resources

### Slow Performance

1. Check resource usage: `docker stats`
2. Restart services: `docker-compose restart`
3. Clear browser cache
4. Clear WordPress cache (if installed)

### Need More Help?

- Check service logs for detailed error messages
- Review the Developer Documentation (DEV_DOC.md)
- Contact your system administrator
