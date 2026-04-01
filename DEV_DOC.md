# DEV_DOC

## Environment setup from scratch
### Prerequisites
- Linux VM
- Docker Engine + Docker Compose plugin
- User has permission to run Docker

### Required local configuration
1. Create secrets in repository root:
- secrets/db_root_password.txt
- secrets/db_password.txt
- secrets/credentials.txt

2. Create env file:
- Copy srcs/.env.example to srcs/.env
- Fill with project-specific values (domain, DB names/users, WP users)

3. Configure local domain resolution:
- Add your login domain to /etc/hosts (example):
- 127.0.0.1 agarcia.42.fr

## Build and launch flow
From repository root:
- make up

Makefile delegates to Docker Compose in srcs/ and creates host data directories:
- /home/agarcia/data/wp_data
- /home/agarcia/data/db_data

## Day-to-day container and volume management
From repository root:
- make ps
- make logs
- make stop
- make start
- make down
- make clean
- make fclean

Direct compose usage (inside srcs/):
- docker compose up --build -d
- docker compose down
- docker compose exec -T mariadb sh
- docker compose exec -T wordpress sh

## Data persistence model
Two named volumes are defined in srcs/docker-compose.yml:
- db_data -> MariaDB data (/var/lib/mysql)
- wp_data -> WordPress files (/var/www/html)

Both are configured to store host data under /home/<login>/data.

## Validation commands
- docker compose ps
- docker volume ls
- docker volume inspect srcs_db_data srcs_wp_data
- echo | openssl s_client -connect localhost:443 -tls1_2
- echo | openssl s_client -connect localhost:443 -tls1_3
- echo | openssl s_client -connect localhost:443 -tls1_1
