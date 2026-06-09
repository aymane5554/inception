#!/bin/sh

cd /var/www/wordpress

until mysqladmin ping -h mariadb -u${MYSQL_USER} -p${MYSQL_PASSWORD} --silent; do
    sleep 2
done

if [ ! -f "/var/www/wordpress/wp-config.php" ]; then
    php -d memory_limit=512M $(which wp) core download --allow-root --path=/var/www/wordpress
    wp config create \
        --dbname=${MYSQL_DATABASE} \
        --dbuser=${MYSQL_USER} \
        --dbpass=${MYSQL_PASSWORD} \
        --dbhost=mariadb:3306 \
        --allow-root --path=/var/www/wordpress

    wp core install \
        --url=${WP_URL} \
        --title=${WP_TITLE} \
        --admin_user=${WP_ADMIN_USER} \
        --admin_password=${WP_ADMIN_PASSWORD} \
        --admin_email=${WP_ADMIN_EMAIL} \
        --allow-root --path=/var/www/wordpress

    wp user create \
        ${WP_USER} \
        ${WP_EMAIL} \
        --user_pass=${WP_PASSWORD} \
        --role=author \
        --allow-root \
        --path=/var/www/wordpress
fi

chown -R nobody:nobody /var/www/wordpress/wp-content
chmod -R 775 /var/www/wordpress/wp-content

chown -R nobody:nobody /var/www/wordpress

exec /usr/sbin/php-fpm84 -F
