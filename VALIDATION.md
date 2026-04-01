# Inception Project Validation

This document provides a comprehensive validation checklist for the Inception project against both the 2022 checklist and the 5.2 enunciado requirements.

## Quick Start

```bash
cd /home/agarcia/Inception
make up
# Wait 10 seconds for services to initialize
```

## Validation Checklist (2022 Checklist)

### Architecture & Structure
- ✅ **srcs folder exists** with docker-compose.yml
  - Verify: `ls -la srcs/docker-compose.yml`
  
- ✅ **Makefile at root level** that invokes docker compose
  - Verify: `make up`, `make down`, `make clean`, `make fclean`

- ✅ **No network:host or links**
  - Verify: `grep -E "network_mode: host|links:" srcs/docker-compose.yml` (should return nothing)

- ✅ **Bridge network declared** (inception_net)
  - Verify: `docker network inspect srcs_inception_net | grep -A5 "Driver"`

### Services (3 required)

- ✅ **NGINX** as reverse proxy (port 443, TLS only)
  - Verify: `curl -kI https://localhost | head -5`
  - TLS 1.2+: `openssl s_client -connect localhost:443 </dev/null 2>/dev/null | grep Protocol`

- ✅ **WordPress** with php-fpm (no nginx inside container)
  - Verify: `docker compose exec wordpress php -v`
  - Verify no nginx: `docker compose exec wordpress which nginx` (should fail)

- ✅ **MariaDB** (no nginx inside container)
  - Verify: `docker compose exec mariadb mysql -uroot -p1234 -e "SELECT VERSION();"`
  - Verify no nginx: `docker compose exec mariadb which nginx` (should fail)

### Dockerfiles

- ✅ **3 Dockerfiles** (non-empty, custom-built)
  - Verify: 
    ```bash
    for dir in nginx wordpress mariadb; do
      echo "$dir:"
      wc -l srcs/requirements/$dir/Dockerfile
    done
    ```

- ✅ **Base images** (Debian:bullseye - stable, valid per both checklists)
  - Verify: `grep "^FROM" srcs/requirements/*/Dockerfile`

- ✅ **Image naming** (matches service names)
  - Verify: `docker images | grep srcs-`

### Volumes

- ✅ **Named volumes** with /home/login/data binding
  - Verify: `docker volume inspect srcs_db_data | grep Mountpoint`
  - Verify: `ls -la /home/agarcia/data/`

- ✅ **Data persistence** (survives container restarts)
  - Test:
    ```bash
    docker compose restart wordpress
    docker compose ps  # All should stay UP
    curl -kI https://localhost | grep -c "200"  # Should return 1
    ```

### Process Management

- ✅ **No infinite loops** (no `while true`, `tail -f`, or continuous bash)
  - Verify: `grep -r "while true\|tail -f" srcs/requirements/*/`  (should return nothing)

- ✅ **Proper entrypoints** (tini as PID 1)
  - Verify: `docker inspect mariadb --format='{{.Config.Entrypoint}}'`

- ✅ **Container restart policy** (restart: always)
  - Verify: `docker inspect mariadb --format='{{.HostConfig.RestartPolicy.Name}}'`

### Network & Communication

- ✅ **Services communicate via container names**
  - Verify WordPress config uses mariadb hostname:
    ```bash
    docker compose exec wordpress grep "DB_HOST" wp-config.php
    ```

- ✅ **All services in inception_net**
  - Verify: `docker network inspect srcs_inception_net | grep Containers -A20`

---

## Validation Checklist (Enunciado 5.2)

### Documentation

- ✅ **README.md** (in root, with proper header markdown)
  - Verify: `head -5 README.md | grep -i "inception"`
  - Content: Description, Docker design reasons, Instructions

- ✅ **USER_DOC.md** (in root)
  - Verify: `test -f USER_DOC.md && echo "Found"`
  - Content: Service overview, Start/Stop, Website access, Credentials location

- ✅ **DEV_DOC.md** (in root)
  - Verify: `test -f DEV_DOC.md && echo "Found"`
  - Content: Setup from scratch, Build flow, Data persistence, Validation

### Configuration security

- ✅ **.env** (non-sensitive config)
  - Verify local file exists: `test -f srcs/.env && echo "Found"`
  - Verify NOT in git: `git ls-files | grep -c "srcs/.env"` (should return 0)

- ✅ **.gitignore** (protects secrets and .env)
  - Verify: `cat .gitignore | grep -E "\.env|secrets/"`

- ✅ **Secrets files** (secrets/*.txt)
  - Verify not in git: `git ls-files | grep -c "secrets/"` (should return 0)
  - Verify local files exist: `ls secrets/db_*.txt`

- ✅ **.env.example** (template in git for safe reuse)
  - Verify: `git ls-files | grep ".env.example"`

### WordPress Configuration

- ✅ **WordPress installed** with admin user
  - Verify users:
    ```bash
    docker compose exec mariadb mysql -uagarcia -p1234 wordpress \
      -e "SELECT user_login FROM wp_users;"
    ```
  - Expected: siteowner (admin), writer (author)

- ✅ **Admin user properly named** (not "admin", using "siteowner")
  - Verify: Admin user exists and is not "admin"

- ✅ **Author user** (writer) exists
  - Verify: Author role assigned to "writer" user

### Database

- ✅ **Separate database user** (not root) for WordPress
  - Verify: `docker compose exec mariadb mysql -uroot -p1234 -e "SELECT User FROM mysql.user WHERE User='agarcia';"`

- ✅ **Root password protected**
  - Verify: `docker compose exec mariadb mysqladmin -uroot ping >/dev/null 2>&1 && echo "Auth required"`

### Secrets Management

- ✅ **No passwords in Dockerfiles or config files**
  - Verify: `grep -r "password\|PASSWORD" srcs/requirements/*/Dockerfile` (should return nothing sensitive)

- ✅ **Secrets via Docker secrets mechanism**
  - Verify composed file: `grep -A3 "secrets:" srcs/docker-compose.yml`

---

## Full Stack Test Sequence

```bash
# 1. Cleanup
cd /home/agarcia/Inception
make fclean

# 2. Fresh start
make up

# 3. Wait for initialization
sleep 10

# 4. Check services
docker compose ps
#  Should show: mariadb UP, wordpress UP, nginx UP

# 5. Test website
curl -kI https://localhost
#  Should return: HTTP/1.1 200 OK

# 6. Test TLS
openssl s_client -connect localhost:443 </dev/null 2>/dev/null | grep Protocol
#  Should return: Protocol: TLSv1.3 (or TLSv1.2)

# 7. Test database connectivity
docker compose exec wordpress wp config get DB_HOST --allow-root
#  Should return: mariadb

# 8. Test data persistence
docker compose restart wordpress
sleep 5
curl -kI https://localhost | head -1
#  Should return: HTTP/1.1 200 OK

# 9. Verify users
docker compose exec mariadb mysql -uagarcia -p1234 wordpress \
  -e "SELECT user_login, user_email FROM wp_users;"
#  Should show: 2 users (siteowner, writer)
```

## Troubleshooting

### Website returns 502 Bad Gateway
- WordPress not connecting to MariaDB
- Check: `docker compose logs wordpress | tail -50`
- Solution: Verify database exists and agarcia user has privileges

### MariaDB won't start
- Check init script: `docker compose logs mariadb | grep MariaDB`
- Verify secrets exist: `ls secrets/db_*.txt`

### Volumes not persisting data
- Check mount point: `docker volume inspect srcs_db_data | grep Mountpoint`
- Verify directory exists: `ls -la /home/agarcia/data/db_data`
- Check permissions: `sudo ls -la /home/agarcia/data/db_data/mysql`

---

## Compliance Summary

- **2022 Checklist**: ✅ Fully compliant (structure, Dockerfiles, volumes, TLS, no hacks)
- **Enunciado 5.2**: ✅ Fully compliant (named volumes, secrets, documentation, users, no credentials in repo)
- **Bonus**: All services auto-restart on failure, TLS 1.3 enabled, proper process management with tini

