#!/bin/sh
set -eu

# Check required environment variables
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_HOST:=mariadb}"
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
: "${WP_TITLE:?WP_TITLE is required}"
: "${WP_ADMIN_USR:?WP_ADMIN_USR is required}"
: "${WP_ADMIN_PWD:?WP_ADMIN_PWD is required}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL is required}"
: "${WP_USR:?WP_USR is required}"
: "${WP_PWD:?WP_PWD is required}"
: "${WP_EMAIL:?WP_EMAIL is required}"

# Get DB password from file or environment variable
if [ -n "${DB_PASSWORD_FILE:-}" ] && [ -f "$DB_PASSWORD_FILE" ]; then
	DB_PASSWORD="$(cat "$DB_PASSWORD_FILE")"
elif [ -n "${DB_PWD:-}" ]; then
	DB_PASSWORD="$DB_PWD"
else
	echo "DB password not found (DB_PASSWORD_FILE or DB_PWD)"
	exit 1
fi

# Initialize WordPress
mkdir -p /run/php /var/www/html # Ensure the directory exists before changing ownership
chown -R www-data:www-data /var/www/html # Ensure www-data owns the directory for WordPress installation
cd /var/www/html

# Download WordPress core files if not already present
if [ ! -f /var/www/html/wp-load.php ]; then
	wp core download --allow-root
fi

# Create wp-config.php if it doesn't exist
if [ ! -f /var/www/html/wp-config.php ]; then
	wp config create \
		--dbname="$DB_NAME" \
		--dbuser="$DB_USER" \
		--dbpass="$DB_PASSWORD" \
		--dbhost="$DB_HOST" \
		--allow-root
fi

# Wait for the database to be ready
until mysqladmin ping -h"$DB_HOST" --silent; do
	sleep 2
done

# Install WordPress if not already installed
if ! wp core is-installed --allow-root; then
	wp core install \
		--url="$DOMAIN_NAME" \
		--title="$WP_TITLE" \
		--admin_user="$WP_ADMIN_USR" \
		--admin_password="$WP_ADMIN_PWD" \
		--admin_email="$WP_ADMIN_EMAIL" \
		--skip-email \
		--allow-root
fi

# Create additional user if it doesn't exist
if ! wp user get "$WP_USR" --allow-root >/dev/null 2>&1; then
	wp user create "$WP_USR" "$WP_EMAIL" --role=author --user_pass="$WP_PWD" --allow-root
fi

exec /usr/sbin/php-fpm7.4 -F
