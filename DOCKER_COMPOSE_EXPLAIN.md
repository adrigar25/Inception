# Guía Completa de Docker Compose

## ¿Qué es Docker Compose?

Docker Compose es una herramienta que permite definir y ejecutar aplicaciones Docker multi-contenedor usando un archivo YAML. En lugar de ejecutar múltiples comandos `docker run`, defines todo en un archivo `docker-compose.yml`.

**Ventajas:**
- Define toda la aplicación en un archivo
- Orquesta múltiples contenedores
- Maneja redes automáticamente
- Gestiona volúmenes y variables de entorno
- Facilita start/stop de toda la aplicación con un comando

---

## Estructura Básica de docker-compose.yml

```yaml
version: '3.8'

services:
  nginx:
    build: ./nginx
    container_name: nginx_container
    ports:
      - "80:80"
    
  wordpress:
    build: ./wordpress
    container_name: wordpress_container
    
  mariadb:
    build: ./mariadb
    container_name: mariadb_container

volumes:
  wordpress_data:
  db_data:

networks:
  default:
    driver: bridge
```

---

## Secciones Principales

### 1. **version**
Especifica la versión del formato de docker-compose.

```yaml
version: '3.8'
```

**Versiones comunes:**
- `'3.0'` - Compatible con Docker 1.13.1+
- `'3.5'` - Docker 17.06.1+
- `'3.8'` - Docker 19.03.0+ (con soporte de placeholders)
- `'3.9'` - Docker 20.10+

**Nota:** La sintaxis y características disponibles dependen de la versión.

---

## Sección: services

Define todos los contenedores que compose ejecutará.

```yaml
services:
  nginx:
    # configuración nginx
  
  wordpress:
    # configuración wordpress
  
  mariadb:
    # configuración mariadb
```

Cada servicio se convierte en un contenedor. El nombre del servicio (nginx, wordpress, mariadb) se usa para:
- Comunicación entre contenedores
- Referenciación en logs
- Nombre en la red

---

## Propiedades de un Servicio

### **build**
Construye la imagen desde un Dockerfile.

```yaml
services:
  nginx:
    build: ./nginx                    # Ruta al Dockerfile
    
  wordpress:
    build:
      context: ./wordpress            # Directorio del Dockerfile
      dockerfile: Dockerfile          # Nombre del Dockerfile (default)
      
  custom:
    build:
      context: ./custom
      dockerfile: Dockerfile.prod
      args:
        BUILD_DATE: 2024-01-01
        VERSION: 1.0
```

**Características:**
- `context`: Directorio donde está el Dockerfile
- `dockerfile`: Nombre del Dockerfile (default: "Dockerfile")
- `args`: Argumentos para el `docker build` (ARG en Dockerfile)

---

### **image**
Especifica la imagen a usar (sin construir).

```yaml
services:
  nginx:
    image: nginx:latest              # Imagen pública
    
  wordpress:
    image: my-repo/wordpress:1.0     # Imagen personalizada
    
  mariadb:
    image: mariadb:latest
```

**Nota:** Si usas `build`, se crea la imagen primero. Si usas `image`, intenta descargarla.

---

### **container_name**
Nombre del contenedor (en lugar del nombre automático).

```yaml
services:
  nginx:
    image: nginx:latest
    container_name: nginx_server      # Nombre personalizado
    
  wordpress:
    image: wordpress:latest
    container_name: wordpress_app     # Sin sufijo de compose
```

**Importante:** Si no especificas, el nombre es: `proyecto_servicio_1` (proyacto_nginx_1, etc.)

---

### **ports**
Mapea puertos entre host y contenedor.

```yaml
services:
  nginx:
    image: nginx:latest
    ports:
      - "80:80"                       # host:contenedor
      - "443:443"                     # HTTPS
      - "8080:80"                     # Puerto host diferente
      - "127.0.0.1:3000:3000"        # Solo localhost
      - "5000:5000/udp"              # UDP (por defecto TCP)
```

**Sintaxis:**
```
[HOST_IP:]HOST_PORT:CONTAINER_PORT[/PROTOCOL]
```

**Ejemplos:**
```yaml
ports:
  - "80:80"              # Accesible desde cualquier IP del host
  - "127.0.0.1:80:80"    # Solo desde localhost
  - "3306:3306/tcp"      # Protocolo TCP
  - "5353:5353/udp"      # Protocolo UDP
```

---

### **expose**
Expone puertos para otros servicios (sin mapear al host).

```yaml
services:
  mariadb:
    image: mariadb:latest
    expose:
      - "3306"           # Accesible para otros servicios, no desde host
```

**Diferencia con ports:**
- `expose`: Solo entre servicios de compose, no desde el host
- `ports`: Desde el host y entre servicios

---

### **environment**
Define variables de entorno.

```yaml
services:
  wordpress:
    image: wordpress:latest
    environment:
      WORDPRESS_DB_HOST: mariadb
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: secreto
      WORDPRESS_DB_NAME: wordpress
      
  mariadb:
    image: mariadb:latest
    environment:
      MYSQL_ROOT_PASSWORD: root_pass
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress_pass
```

**Equivalente con `docker run`:**
```bash
docker run -e VARIABLE=valor imagen
```

---

### **env_file**
Lee variables de entorno desde un archivo.

```yaml
services:
  wordpress:
    image: wordpress:latest
    env_file:
      - .env                    # Un archivo
      
  custom:
    image: custom:latest
    env_file:
      - .env
      - .env.local             # Múltiples archivos
```

**Archivo `.env`:**
```
WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=secreto
```

**Ventaja:** Las credenciales no están en el docker-compose.yml.

---

### **volumes**
Monta directorios o volúmenes en el contenedor.

```yaml
services:
  nginx:
    image: nginx:latest
    volumes:
      - ./conf:/etc/nginx           # Bind mount (directorio)
      - /var/log/nginx              # Volumen nombrado
      
  wordpress:
    image: wordpress:latest
    volumes:
      - wordpress_data:/var/www/html  # Volumen nombrado
      - ./uploads:/var/www/html/wp-content/uploads
      
  mariadb:
    image: mariadb:latest
    volumes:
      - db_data:/var/lib/mysql      # Volumen nombrado
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro  # Read-only

volumes:
  wordpress_data:                   # Definir volumen
  db_data:
```

**Tipos de volúmenes:**

1. **Bind mount** (Directorio del host)
```yaml
volumes:
  - ./conf:/etc/nginx              # ./conf (relativo) → /etc/nginx (contenedor)
  - /full/path:/etc/app           # Ruta absoluta
  - ./data:/data:rw               # Read-write (default)
  - ./config:/etc/config:ro       # Read-only
```

2. **Volumen nombrado** (Gestionado por Docker)
```yaml
services:
  db:
    volumes:
      - my_data:/var/lib/mysql

volumes:
  my_data:                         # Definición del volumen
```

3. **Volumen anónimo**
```yaml
volumes:
  - /var/log/app                   # Sin definición en sección volumes
```

**Opciones de volumen:**
- `rw`: read-write (default)
- `ro`: read-only
- `nocopy`: No copiar datos iniciales

---

### **depends_on**
Define orden de inicio de servicios.

```yaml
services:
  wordpress:
    image: wordpress:latest
    depends_on:
      - mariadb                    # Inicia mariadb primero
      
  mariadb:
    image: mariadb:latest
```

**Importante:** Solo garantiza orden, no que el servicio esté listo.

**Para esperar a que esté listo:**
```yaml
services:
  wordpress:
    image: wordpress:latest
    depends_on:
      mariadb:
        condition: service_healthy  # Espera a healthcheck
        
  mariadb:
    image: mariadb:latest
    healthcheck:
      test: ["CMD", "mysqladmin", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

---

### **networks**
Define redes personalizadas para comunicación entre servicios.

```yaml
services:
  nginx:
    image: nginx:latest
    networks:
      - frontend                   # Red 1
      
  wordpress:
    image: wordpress:latest
    networks:
      - frontend
      - backend                    # Red 2
      
  mariadb:
    image: mariadb:latest
    networks:
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

**Drivers de red:**
- `bridge`: Red aislada (default)
- `host`: Usa la red del host
- `overlay`: Para Docker Swarm
- `none`: Sin red

**Comunicación entre servicios:**
```
Por nombre del servicio (Docker resuelve DNS):
wordpress conecta a mariadb → http://mariadb:3306
```

---

### **restart**
Política de reinicio del contenedor.

```yaml
services:
  nginx:
    image: nginx:latest
    restart: always               # Siempre reiniciar
    
  wordpress:
    image: wordpress:latest
    restart: unless-stopped       # Excepto si fue parado manualmente
    
  mariadb:
    image: mariadb:latest
    restart: on-failure           # Solo si falló
```

**Opciones:**
- `no`: No reiniciar (default)
- `always`: Siempre reiniciar, incluso si exited
- `unless-stopped`: Igual que always, pero respeta stop manual
- `on-failure`: Solo reinicia si exit code ≠ 0
- `on-failure:5`: Máximo 5 reintentos

---

### **healthcheck**
Define cómo verificar si el contenedor está saludable.

```yaml
services:
  mariadb:
    image: mariadb:latest
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s               # Cada 10 segundos
      timeout: 5s                 # Esperar 5 segundos
      retries: 3                  # Máximo 3 intentos
      start_period: 40s           # Esperar antes de empezar
```

**Estados:**
- `starting`: Dentro del start_period
- `healthy`: El test pasó
- `unhealthy`: El test falló
- `none`: Sin healthcheck

---

### **stdin_open** y **tty**
Mantiene STDIN abierto y TTY interactivo.

```yaml
services:
  app:
    image: app:latest
    stdin_open: true              # -i (docker run)
    tty: true                     # -t (docker run)
```

**Equivalente a:**
```bash
docker run -it imagen
```

---

### **working_dir**
Establece directorio de trabajo.

```yaml
services:
  app:
    image: node:14
    working_dir: /app
    command: npm start
```

**Equivalente Dockerfile:**
```dockerfile
WORKDIR /app
```

---

### **command** y **entrypoint**
Anula el comando o entrypoint del Dockerfile.

```yaml
services:
  app:
    image: node:14
    command: npm start            # Anula CMD
    
  db:
    image: postgres:latest
    entrypoint: ["custom-script"]  # Anula ENTRYPOINT
    command: ["start"]             # Argumentos para entrypoint
```

**Equivalente docker run:**
```bash
docker run -e entrypoint=["custom"] --command ["start"] imagen
```

---

### **user**
Especifica usuario que ejecuta el contenedor.

```yaml
services:
  app:
    image: app:latest
    user: "1000:1000"             # UID:GID
```

---

### **privileged**
Da permisos de root al contenedor (peligroso).

```yaml
services:
  sys_admin:
    image: ubuntu:latest
    privileged: true              # Acceso total al host
```

---

### **devices**
Mapea dispositivos del host.

```yaml
services:
  gpu_app:
    image: gpu_app:latest
    devices:
      - /dev/nvidia0              # GPU NVIDIA
      - /dev/ttyUSB0              # Puerto serial
```

---

### **cap_add** y **cap_drop**
Añade/elimina Linux capabilities.

```yaml
services:
  app:
    image: app:latest
    cap_add:
      - NET_ADMIN                 # Administración de red
      - SYS_TIME                  # Cambiar hora
    cap_drop:
      - ALL                       # Eliminar todas
```

---

### **labels**
Metadatos del contenedor.

```yaml
services:
  nginx:
    image: nginx:latest
    labels:
      maintainer: "usuario@example.com"
      version: "1.0"
      environment: "production"
```

---

### **logging**
Configuración de logs.

```yaml
services:
  app:
    image: app:latest
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## Sección: volumes

Define volúmenes nombrados que se comparten entre servicios.

```yaml
volumes:
  wordpress_data:
    driver: local
    
  db_data:
    driver: local
    driver_opts:
      type: tmpfs
      device: tmpfs
      o: size=100m,uid=1000
```

**Drivers:**
- `local`: Sistema de archivos local (default)
- `nfs`: Network File System
- Custom drivers

---

## Sección: networks

Define redes personalizadas.

```yaml
networks:
  frontend:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: br0
      
  backend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
          gateway: 172.28.0.1
```

**Opciones:**
- `driver`: Tipo de red (bridge, overlay, host, etc.)
- `driver_opts`: Opciones del driver
- `ipam`: Configuración de IP

---

## Ejemplo Completo: Tu Proyecto Inception

```yaml
version: '3.8'

services:
  # Servicio NGINX
  nginx:
    build:
      context: ./srcs/requirements/nginx
      dockerfile: Dockerfile
    container_name: nginx_container
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./srcs/requirements/nginx/conf/default.conf:/etc/nginx/sites-available/default:ro
      - ./srcs/requirements/nginx/conf/nginx.conf:/etc/nginx/nginx.conf:ro
      - wordpress_data:/var/www/html:rw
    networks:
      - network
    depends_on:
      - wordpress

  # Servicio WordPress
  wordpress:
    build:
      context: ./srcs/requirements/wordpress
      dockerfile: Dockerfile
    container_name: wordpress_container
    restart: unless-stopped
    environment:
      - WORDPRESS_DB_HOST=mariadb
      - WORDPRESS_DB_USER=wordpress
      - WORDPRESS_DB_PASSWORD=wordpress_pass
      - WORDPRESS_DB_NAME=wordpress
    env_file:
      - ./secrets/.env
    volumes:
      - wordpress_data:/var/www/html:rw
    networks:
      - network
    depends_on:
      mariadb:
        condition: service_healthy

  # Servicio MariaDB
  mariadb:
    build:
      context: ./srcs/requirements/mariadb
      dockerfile: Dockerfile
    container_name: mariadb_container
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=root_password
      - MYSQL_DATABASE=wordpress
      - MYSQL_USER=wordpress
      - MYSQL_PASSWORD=wordpress_pass
    env_file:
      - ./secrets/.env
    volumes:
      - db_data:/var/lib/mysql:rw
    networks:
      - network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 40s

# Sección de volúmenes
volumes:
  wordpress_data:
    driver: local
  db_data:
    driver: local

# Sección de redes
networks:
  network:
    driver: bridge
```

---

## Comandos Útiles

```bash
# Iniciar servicios
docker-compose up

# Iniciar en background
docker-compose up -d

# Ver logs
docker-compose logs
docker-compose logs nginx          # Log de un servicio específico
docker-compose logs -f             # Seguir logs (tail -f)

# Parar servicios
docker-compose stop

# Eliminar contenedores (sin volúmenes)
docker-compose down

# Eliminar todo incluyendo volúmenes
docker-compose down -v

# Reconstruir imágenes
docker-compose build

# Ver estado
docker-compose ps

# Ejecutar comando en servicio
docker-compose exec wordpress bash
docker-compose run wordpress whoami

# Ver configuración resolvida
docker-compose config

# Validar syntaxis
docker-compose config --quiet
```

---

## Buenas Prácticas

### 1. **Usa versiones específicas**
```yaml
# ❌ MALO
image: nginx:latest

# ✅ BUENO
image: nginx:1.25.1
```

### 2. **Organiza servicios por función**
```yaml
services:
  # Web servers
  nginx:
    ...
  # Applications
  wordpress:
    ...
  # Databases
  mariadb:
    ...
```

### 3. **Usa networks en lugar de links**
```yaml
# ❌ VIEJO
links:
  - mariadb:database

# ✅ NUEVO
networks:
  - default
```

### 4. **Seguridad: usa variables de entorno**
```yaml
# ❌ MALO - Credenciales en texto plano
environment:
  MYSQL_PASSWORD: secreto123

# ✅ BUENO - Archivo externo
env_file:
  - .env
```

### 5. **Especifica dependencias**
```yaml
depends_on:
  mariadb:
    condition: service_healthy  # Espera a que esté listo
```

### 6. **Usa políticas de reinicio**
```yaml
restart: unless-stopped
```

### 7. **Especifica recursos (versión 2.4+)**
```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

---

## Resolución de Problemas

### El servicio no está listo cuando otro intenta conectar
**Solución:** Usa `condition: service_healthy` con healthcheck

### Los contenedores no pueden comunicarse
**Solución:** Asegúrate de que estén en la misma red

### El volumen no persiste datos
**Solución:** Verifica que el volumen esté correctamente montado

### Puerto ya en uso
```bash
# Ver qué proceso usa el puerto
lsof -i :80

# Usar puerto diferente
ports:
  - "8080:80"
```

---

## Resumen Rápido

| Propiedad | Propósito |
|---|---|
| service_name | Nombre del contenedor |
| build | Construir desde Dockerfile |
| image | Usar imagen existente |
| container_name | Nombre personalizado |
| ports | Mapear puertos |
| expose | Exponer entre servicios |
| environment | Variables de entorno |
| env_file | Variables desde archivo |
| volumes | Persistencia de datos |
| networks | Comunicación entre servicios |
| restart | Política de reinicio |
| healthcheck | Verificar salud |
| depends_on | Orden de inicio |
| command | Anular CMD |
| user | Usuario de ejecución |

