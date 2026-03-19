#!/bin/bash

service mariadb start

sleep 2

mysql -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE;"

mysql -e "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';"

mysql -e "GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%';"

mysql -e "FLUSH PRIVILEGES;"

mysqladmin -u root shutdown

exec mysqld_safe
