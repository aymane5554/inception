#!/bin/sh
set -e

WP_PATH=/var/www/wordpress

# Wait for MariaDB to be ready before doing anything
echo "Waiting for MariaDB..."
until mysqladmin ping -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent; do
    sleep 2
done
echo "MariaDB is up!"

# Only install WordPress if it's not already installed
# (prevents reinstalling on container restart)
if [ ! -f "$WP_PATH/wp-config.php" ]; then

    echo "Downloading WordPress..."
    wp core download \
        --path="$WP_PATH" \
        --allow-root

    echo "Creating wp-config.php..."
    wp config create \
        --path="$WP_PATH" \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_PASSWORD" \
        --dbhost="$MYSQL_HOST" \
        --allow-root

    echo "Installing WordPress..."
    wp core install \
        --path="$WP_PATH" \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --allow-root

    echo "Creating second WordPress user..."
    wp user create \
        "$WP_USER" "$WP_USER_EMAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --role=author \
        --path="$WP_PATH" \
        --allow-root

    # Fix permissions for php-fpm running as nobody
    chown -R nobody:nobody "$WP_PATH"
    find "$WP_PATH" -type d -exec chmod 755 {} \;
    find "$WP_PATH" -type f -exec chmod 644 {} \;

    echo "WordPress setup complete!"
fi

echo "Starting php-fpm..."
# Run php-fpm in the foreground — required for Docker PID 1
exec php-fpm82 -F