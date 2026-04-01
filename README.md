*This project has been created as part of the 42 curriculum by agarcia.*

## Description
Inception is a System Administration project where a small production-like web stack is deployed with Docker Compose inside a VM.

The mandatory stack includes:
- NGINX (TLS only)
- WordPress with php-fpm (without NGINX inside the container)
- MariaDB (without NGINX inside the container)

The project demonstrates container isolation, service orchestration, persistent data, and secure configuration through environment variables and Docker secrets.

## Project Design Choices
### Docker in this project
Docker packages each service with its own filesystem, runtime, and dependencies. Docker Compose defines how services are built, connected, and started together.

### Sources included
- Docker Compose definition: srcs/docker-compose.yml
- Service Dockerfiles: srcs/requirements/*/Dockerfile
- Service configs/scripts: srcs/requirements/*/conf and srcs/requirements/*/tools
- Secrets (local only): secrets/

### Virtual Machines vs Docker
- Virtual Machines: full guest OS, stronger isolation, heavier resource usage, slower startup.
- Docker: process-level isolation on host kernel, lightweight, fast startup, easier reproducibility.

### Secrets vs Environment Variables
- Environment variables are convenient for non-sensitive configuration (domain, usernames, titles).
- Docker secrets are better for sensitive values (database passwords) because they are mounted as files and avoid exposing credentials in image layers.

### Docker Network vs Host Network
- Docker bridge networks isolate service communication and provide internal DNS by service name.
- Host network removes network isolation and is forbidden by the project requirements.

### Docker Volumes vs Bind Mounts
- Named volumes are managed by Docker and fit container persistence workflows.
- Bind mounts directly map host paths and are more coupled to host filesystem layout.
- This project uses Docker named volumes with host storage under /home/<login>/data as required.

## Instructions
### Prerequisites
- Linux VM
- Docker and Docker Compose installed
- Local domain mapping in /etc/hosts

Example /etc/hosts entry:
- 127.0.0.1 agarcia.42.fr

### Initial setup
1. Create local secret files:
- secrets/db_root_password.txt
- secrets/db_password.txt
- secrets/credentials.txt

2. Create srcs/.env from srcs/.env.example and set your real values.

3. Start services from repository root:
- make up

### Useful commands
- Build and run: make up
- Stop: make down
- Logs: make logs
- Status: make ps
- Full cleanup: make fclean

## Resources
- Docker documentation: https://docs.docker.com/
- Docker Compose specification: https://docs.docker.com/compose/
- NGINX documentation: https://nginx.org/en/docs/
- MariaDB documentation: https://mariadb.com/kb/en/documentation/
- WordPress + WP-CLI docs: https://developer.wordpress.org/ and https://wp-cli.org/

### AI usage statement
AI was used to:
- review Docker and Compose configuration consistency,
- identify runtime/build issues,
- improve startup scripts and validation checks,
- draft documentation structure.

All generated suggestions were reviewed, tested locally, and adapted before use.
