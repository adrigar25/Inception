#!/bin/sh
set -eu

: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"

if [ -n "${DB_ROOT_PASSWORD_FILE:-}" ] && [ -f "$DB_ROOT_PASSWORD_FILE" ]; then
	DB_ROOT_PASSWORD="$(cat "$DB_ROOT_PASSWORD_FILE")"
elif [ -n "${DB_ROOT_PWD:-}" ]; then
	DB_ROOT_PASSWORD="$DB_ROOT_PWD"
else
	echo "DB root password not found (DB_ROOT_PASSWORD_FILE or DB_ROOT_PWD)"
	exit 1
fi

if [ -n "${DB_PASSWORD_FILE:-}" ] && [ -f "$DB_PASSWORD_FILE" ]; then
	DB_PASSWORD="$(cat "$DB_PASSWORD_FILE")"
elif [ -n "${DB_PWD:-}" ]; then
	DB_PASSWORD="$DB_PWD"
else
	echo "DB user password not found (DB_PASSWORD_FILE or DB_PWD)"
	exit 1
fi

mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
	echo "[MariaDB Init] First boot: initializing database..." >&2
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql

	echo "[MariaDB Init] Starting temporary MySQL instance for setup..." >&2
	mysqld --user=mysql --skip-networking --socket=/run/mysqld/mysqld.sock --datadir=/var/lib/mysql &
	SETUP_PID=$!

	echo "[MariaDB Init] Waiting for MySQL to be ready..." >&2
	for i in $(seq 1 30); do
		if mysqladmin --socket=/run/mysqld/mysqld.sock ping --silent 2>/dev/null; then
			break
		fi
		sleep 1
	done

	echo "[MariaDB Init] Setting up root password and database..." >&2
	mysql --socket=/run/mysqld/mysqld.sock <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
	SETUP_RESULT=$?
	echo "[MariaDB Init] Database setup completed with code: $SETUP_RESULT" >&2

	echo "[MariaDB Init] Shutting down temporary instance..." >&2
	kill $SETUP_PID 2>/dev/null || true
	wait $SETUP_PID 2>/dev/null || true
	echo "[MariaDB Init] Temporary instance shut down" >&2
fi

exec mysqld --user=mysql --console
