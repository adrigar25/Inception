FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
	php-fpm \
	php-mysql \
	mariadb-client \
	curl \
	ca-certificates \
	less \
	unzip \
	tini \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
	&& chmod +x /usr/local/bin/wp

COPY conf/www.conf /etc/php/7.4/fpm/pool.d/www.conf
COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh \
	&& mkdir -p /run/php /var/www/html \
	&& chown -R www-data:www-data /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/init.sh"]
