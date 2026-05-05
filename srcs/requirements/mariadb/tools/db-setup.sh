#!/bin/sh
set -e

# Only initialize if the data directory is empty
# Prevents re-initialization on every container restart
if [ ! -d "/var/lib/mysql/mysql" ]; then

    echo "Initializing MariaDB data directory..."

    # mysql_install_db sets up the system tables
    # --user=mysql runs it as the mysql user (not root)
    # --datadir points to where data will live
    mysql_install_db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --skip-test-db \
        > /dev/null

    echo "Data directory initialized."

    # Start MariaDB temporarily in the background
    # so we can run SQL commands to create our DB and users
    mysqld --user=mysql --bootstrap << EOF

-- Use the built-in mysql database for setup
USE mysql;

-- Flush any cached privileges
FLUSH PRIVILEGES;

-- Remove anonymous users (security)
DELETE FROM mysql.user WHERE User='';

-- Remove remote root login (security)
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

-- Create the WordPress database
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

-- Create the WordPress user with access from any host
-- (WordPress container connects from a different IP)
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

-- Grant all privileges on the WordPress database to that user
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

-- Apply privilege changes
FLUSH PRIVILEGES;

EOF

    echo "Database '${MYSQL_DATABASE}' and user '${MYSQL_USER}' created."

fi

echo "Starting MariaDB..."

# exec replaces the shell with mysqld — makes it PID 1
# --user=mysql avoids running as root
# --console keeps logs going to stdout (visible with docker logs)
exec mysqld --user=mysql --console