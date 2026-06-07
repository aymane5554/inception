FROM alpine:3.22

RUN apk add --no-cache mariadb mariadb-client

RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld

COPY conf/mariadb.conf /etc/my.cnf.d/mariadb-server.cnf

COPY  tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

ENTRYPOINT [ "/usr/local/bin/init.sh" ]
