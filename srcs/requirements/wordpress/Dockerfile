FROM alpine:3.22

WORKDIR /var/www/wordpress

COPY tools/wp_init.sh /usr/local/bin/wp_init.sh

RUN apk update && apk add php84 php84-fpm php84-mysqli php84-phar php84-mbstring php84-tokenizer curl mariadb-client

RUN ln -s /usr/bin/php84 /usr/bin/php

RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp

RUN chmod +x /usr/local/bin/wp /usr/local/bin/wp_init.sh

RUN sed -i 's/listen = 127.0.0.1:9000/listen = 9000/g' /etc/php84/php-fpm.d/www.conf

ENTRYPOINT ["/usr/local/bin/wp_init.sh"]
