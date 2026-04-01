# USER_DOC

## What services are provided
This stack provides:
- NGINX reverse proxy with TLS (entrypoint on port 443)
- WordPress application running with php-fpm
- MariaDB database backend

## Start and stop the project
From repository root:
- Start/build: make up
- Stop: make down
- Show logs: make logs
- Show containers: make ps

## Access the website and admin panel
1. Ensure your local host resolves the domain (example):
- 127.0.0.1 agarcia.42.fr in /etc/hosts

2. Open:
- Website: https://agarcia.42.fr
- Admin panel: https://agarcia.42.fr/wp-admin

A browser warning about a self-signed certificate is expected.

## Credentials location and management
- Non-sensitive configuration: srcs/.env (local file, not committed)
- Sensitive credentials: secrets/*.txt (local files, not committed)

Expected secret files:
- secrets/db_root_password.txt
- secrets/db_password.txt
- secrets/credentials.txt

If credentials are changed, restart the stack:
- make down
- make up

## Health checks
From srcs directory:
- docker compose ps
- docker compose logs --tail=80

Quick endpoint checks:
- curl -kI https://agarcia.42.fr
- curl -I http://localhost (should fail or refuse)
