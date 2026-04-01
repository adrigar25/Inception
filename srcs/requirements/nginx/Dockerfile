FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
	nginx \
	openssl \
	tini \
	&& rm -rf /var/lib/apt/lists/*

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/default.conf /etc/nginx/conf.d/default.conf
COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh && mkdir -p /etc/nginx/ssl

EXPOSE 443

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/init.sh"]
