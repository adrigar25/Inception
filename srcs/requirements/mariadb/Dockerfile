FROM debian:bookworm

RUN apt update && apt install -y mariadb-server

COPY conf/my.cnf /etc/mysql/my.cnf
COPY tools/init.sh /init.sh

RUN chmod +x /init.sh

EXPOSE 3306

CMD ["/init.sh"]
