FROM alpine:3.23

WORKDIR /var/www/wordpress

RUN apk update && apk add php84 php84-fpm php84-mysqli php84-phar mariadb-client

RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp

COPY tools/wp_init.sh /usr/local/bin/wp_init.sh

RUN chmod +x /usr/local/bin/wp /usr/local/bin/wp_init.sh

COPY conf/www.conf  /etc/php84/php-fpm.d/www.conf

ENTRYPOINT ["/usr/local/bin/wp_init.sh"]
