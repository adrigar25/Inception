#!/bin/bash
set -e

# Comprobar que las variables existen
: "${MYSQL_DATABASE:?Need to set MYSQL_DATABASE}"
: "${MYSQL_USER:?Need to set MYSQL_USER}"
: "${MYSQL_PASSWORD:?Need to set MYSQL_PASSWORD}"
: "${DOMAIN_NAME:?Need to set DOMAIN_NAME}"
: "${WP_ADMIN_USR:?Need to set WP_ADMIN_USR}"
: "${WP_ADMIN_PWD:?Need to set WP_ADMIN_PWD}"
: "${WP_ADMIN_EMAIL:?Need to set WP_ADMIN_EMAIL}"
: "${WP_USR:?Need to set WP_USR}"
: "${WP_PWD:?Need to set WP_PWD}"
: "${WP_EMAIL:?Need to set WP_EMAIL}"

# Limpiar y preparar directorio
mkdir -p /var/www/html
cd /var/www/html
rm -rf *

# Descargar WordPress
wp core download --allow-root
mv wp-config-sample.php wp-config.php

# Configurar wp-config.php usando env vars
sed -i "s/database/$MYSQL_DATABASE/1" wp-config.php
sed -i "s/database_user/$MYSQL_USER/1" wp-config.php
sed -i "s/passwod/$MYSQL_PASSWORD/1" wp-config.php
sed -i "s/localhost/mariadb/1" wp-config.php

# Instalar WP
wp core install --url=$DOMAIN_NAME --title="Inception Site" \
  --admin_user=$WP_ADMIN_USR --admin_password=$WP_ADMIN_PWD \
  --admin_email=$WP_ADMIN_EMAIL --skip-email --allow-root

# Crear usuario extra
wp user create $WP_USR $WP_EMAIL --role=author --user_pass=$WP_PWD --allow-root

# Tema y plugin
wp theme install astra --activate --allow-root
wp plugin install redis-cache --activate --allow-root
wp redis enable --allow-root

# PHP-FPM en TCP 9000
sed -i 's|listen = /run/php/php7.3-fpm.sock|listen = 9000|g' /etc/php/7.3/fpm/pool.d/www.conf
mkdir -p /run/php

# Arrancar PHP-FPM
/usr/sbin/php-fpm7.3 -F
