# NGINX: Proxy Inverso y Servidor Web

**Propósito**: NGINX actúa como proxy inverso y punto de entrada HTTP/HTTPS para el stack de Inception. Termina conexiones TLS, sirve los archivos estáticos de WordPress y enruta las solicitudes PHP al contenedor PHP-FPM de WordPress.

---

## 1. Dockerfile: Construcción de la Imagen

**Ubicación**: `srcs/requirements/nginx/Dockerfile`

**Propósito**: Construir la imagen del contenedor NGINX con soporte SSL y scripts de inicialización.

### Proceso de Construcción

```dockerfile
FROM debian:bullseye
```
- **Imagen base**: Debian bullseye — igual que MariaDB y WordPress para consistencia
- **Razón**: Estable, bien probada, cumple con los requisitos del checklist de la escuela 42

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
	nginx \
	openssl \
	tini \
	&& rm -rf /var/lib/apt/lists/*
```

**Paquetes clave**:
- `nginx` — Servidor web y proxy inverso
- `openssl` — Herramienta de generación de certificados TLS (usada para certificados autofirmados)
- `tini` — Gestor de procesos (asegura manejo correcto de señales como PID 1)

**Nota**: `--no-install-recommends` mantiene la imagen pequeña omitiendo dependencias opcionales.

```dockerfile
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/default.conf /etc/nginx/conf.d/default.conf
COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh && mkdir -p /etc/nginx/ssl
```

**Configuración**:
- Copiar configuración principal de NGINX a `/etc/nginx/nginx.conf` (configuración global)
- Copiar configuración de host virtual a `/etc/nginx/conf.d/default.conf` (bloque servidor para el dominio Inception)
- Copiar script de inicialización y hacerlo ejecutable
- Crear directorio `/etc/nginx/ssl/` para almacenar certificados

```dockerfile
EXPOSE 443
```
- **Exposición de puerto**: Solo 443 (HTTPS); HTTP (puerto 80) NO está expuesto
- **Cumplimiento**: El checklist explícitamente prohíbe exponer puertos innecesarios
- **Razón**: Todo el tráfico está encriptado; sin alternativa sin cifrar

```dockerfile
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/init.sh"]
```
- **Punto de entrada**: tini → init.sh
- **Razón**: Asegura reenvío correcto de señales (SIGTERM → cierre gracioso de nginx)

---

## 2. nginx.conf: Configuración Global

**Ubicación**: `srcs/requirements/nginx/conf/nginx.conf`

**Propósito**: Definir configuración global de NGINX, políticas de seguridad y comportamiento de logging.

### Gestión de Usuario y Procesos

```nginx
user  www-data;
worker_processes  auto;
pid /run/nginx.pid;
```

- `user www-data` — Los procesos worker de NGINX se ejecutan como www-data (usuario no-root por seguridad)
- `worker_processes auto` — Detectar automáticamente el número de núcleos CPU; crear un worker por núcleo para distribución óptima de carga
- `pid /run/nginx.pid` — Almacenar ID de proceso en ubicación estándar

### Configuración del Event Loop

```nginx
events {
    worker_connections 1024;
}
```

- `worker_connections 1024` — Cada worker puede manejar hasta 1024 conexiones concurrentes
- **Cálculo**: Capacidad total = 1024 × (número de procesos worker)
- **Ejemplo**: Sistema 4-núcleo = 4 workers × 1024 = 4096 conexiones concurrentes totales
- **Para Inception**: Prueba de usuario único; 1024 es más que suficiente

### Bloque HTTP: Protocolos y Configuración de Seguridad

```nginx
http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
```

**Optimización de red**:
- `sendfile on` — Usar transmisión de archivos a nivel de kernel (eficiente para archivos estáticos)
- `tcp_nopush on` — Esperar paquete completo antes de enviar (reduce gastos generales)
- `tcp_nodelay on` — Deshabilitar algoritmo de Nagle; enviar paquetes pequeños inmediatamente (baja latencia para contenido interactivo)
- `keepalive_timeout 65` — Mantener conexión TCP viva por 65 segundos (permite pipelining HTTP)

**Razón para usar ambos nopush + nodelay**: 
- `nopush` usado para datos grandes (archivos estáticos como CSS, JS)
- `nodelay` usado para respuestas interactivas (páginas PHP, formularios)
- NGINX habilita ambos, dejando que el kernel decida cuándo aplicar cada uno

```nginx
    types_hash_max_size 2048;

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
```

- `types_hash_max_size 2048` — Tabla hash para búsquedas de tipo MIME
- `include /etc/nginx/mime.types` — Cargar tipos MIME estándar (image/png, text/html, etc.)
- `default_type application/octet-stream` — Alternativa para tipos de archivo desconocidos (activa comportamiento de descarga)

### Configuración de Seguridad

```nginx
    # Seguridad TLS
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
```

- `ssl_protocols TLSv1.2 TLSv1.3` — Solo aceptar protocolos TLS modernos (TLSv1.0 y TLSv1.1 deshabilitados)
- `ssl_prefer_server_ciphers on` — Usar orden preferido de cifrados del servidor (no del cliente)
- **Cumplimiento**: El checklist prohíbe SSL/TLSv1.0; esto aplica estándares de cifrado moderno

### Configuración de Logging

```nginx
    # Logs
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
```

- `access_log` — Log de solicitudes HTTP (método, URI, código de estado, tiempo de respuesta)
- `error_log` — Errores de NGINX (problemas de inicio, problemas de configuración)
- **Útil para depuración**: Revisar estos durante el desarrollo del contenedor

### Inclusión de Host Virtual

```nginx
    # Incluir configuraciones de los sitios
    include /etc/nginx/conf.d/*.conf;
}
```

- Incluye todos los archivos `.conf` de `/etc/nginx/conf.d/` (donde está ubicado `default.conf`)
- Permite múltiples configuraciones de host virtual en archivos separados
- Mejor práctica Docker: configuración principal + configuraciones por servicio

---

## 3. default.conf: Configuración de Host Virtual

**Ubicación**: `srcs/requirements/nginx/conf/default.conf`

**Propósito**: Definir el bloque servidor HTTPS para agarcia.42.fr y enrutar solicitudes a WordPress.

### Declaración del Bloque Servidor

```nginx
server {
    listen 443 ssl;
    server_name __DOMAIN_NAME__;
```

- `listen 443 ssl` — Escuchar en puerto 443 con SSL/TLS habilitado
- `server_name __DOMAIN_NAME__` — Marcador de posición para nombre de dominio (reemplazado en tiempo de ejecución por init.sh)
- **Sustitución en tiempo de ejecución**: `sed -i "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g"` en init.sh reemplaza con dominio real

**¿Por qué marcador de posición?**
- El Dockerfile en tiempo de ejecución no tiene acceso a la variable de entorno DOMAIN_NAME
- init.sh se ejecuta al iniciar el contenedor con acceso a variables de entorno
- Sustitución dinámica antes de que NGINX se inicie

### Configuración del Certificado TLS

```nginx
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
```

- `ssl_certificate` — Certificado público (autofirmado, generado por init.sh)
- `ssl_certificate_key` — Clave privada (generada con certificado)
- `ssl_protocols` — Aplicar mínimo TLS 1.2 (TLS 1.0/1.1 bloqueados)
- `ssl_ciphers HIGH:!aNULL:!MD5` — Solo cifrados fuertes; sin autenticación anónima o hash MD5

**Certificado autofirmado**:
```
openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout key.pem \
    -out cert.pem \
    -subj "/CN=agarcia.42.fr"
```
- `-x509` — Certificado autofirmado (no firmado por CA)
- `-nodes` — Sin contraseña para clave privada
- `-days 365` — Válido por 1 año
- `-newkey rsa:2048` — Generar clave RSA de 2048 bits (estándar moderno)
- `-subj "/CN=agarcia.42.fr"` — Establecer Nombre Común (coincide con server_name)

### Directorio Raíz y Archivos de Índice

```nginx
    root /var/www/html;
    index index.php index.html index.htm;
```

- `root /var/www/html` — Directorio raíz del documento (donde se sirven archivos de WordPress)
- `index index.php index.html index.htm` — Archivos predeterminados a servir si se solicita un directorio
  - `/` → busca `/index.php` (controlador frontal de WordPress)
  - Alternativa a `.html` o `.htm` si no se encuentra archivo PHP

### Reescritura de URL (URLs Limpias de WordPress)

```nginx
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
```

**Cómo funciona**:
1. Solicitud entra: `GET /blog/hello-world/`
2. Verificar si archivo existe: `$uri` → `/blog/hello-world/` (NO)
3. Verificar si directorio existe: `$uri/` → `/blog/hello-world/` (NO, solo posts en BD)
4. **Alternativa a PHP**: Pasar a `/index.php?args=...`
5. Motor de WordPress procesa la solicitud

**Por qué es importante**:
- WordPress no almacena páginas como archivos en disco; están en la base de datos
- Esta reescritura envía TODAS las solicitudes no existentes a WordPress index.php
- El router de WordPress determina qué contenido servir

**URLs potenciales servidas**:
- `/index.html` → Archivo estático servido directamente
- `/wp-admin/` → Manejado por PHP de WordPress
- `/blog/my-post/` → Manejado por router de WordPress vía index.php

### Proxy Inverso PHP-FPM

```nginx
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
```

**Desglosándolo**:
- `location ~ \.php$` — Coincidir solicitudes para archivos `.php` (patrón regex)
- `include fastcgi_params` — Cargar variables FastCGI estándar (PATH_INFO, REQUEST_METHOD, etc.)
- `fastcgi_pass wordpress:9000` — Reenviar solicitud a servicio PHP-FPM en `wordpress:9000`
  - `wordpress` — Nombre del servicio Docker (resuelto vía DNS de Docker)
  - `9000` — Puerto donde PHP-FPM escucha (configurado en www.conf)
- `fastcgi_index index.php` — Usar index.php si solo se especifica un directorio
- `fastcgi_param SCRIPT_FILENAME` — Indicar a PHP-FPM la ruta completa del archivo en disco

**Flujo de comunicación**:
```
NGINX (puerto 443) 
  ↓ (protocolo FastCGI)
PHP-FPM (puerto 9000, dentro del contenedor wordpress)
  ↓ (consultas SQL)
MariaDB (puerto 3306, dentro del contenedor mariadb)
```

### Bloqueo de .htaccess

```nginx
    location ~ /\.ht {
        deny all;
    }
```

- Bloquear acceso a archivos `.htaccess` (específico de Apache, no usado en NGINX)
- Previene que atacantes descarguen archivos de configuración sensibles
- `location ~ /\.ht` — Coincidir cualquier archivo/directorio que comience con `.ht`
- `deny all` — Devolver 403 Prohibido

---

## 4. init.sh: Script de Inicio

**Ubicación**: `srcs/requirements/nginx/tools/init.sh`

**Propósito**: Generar certificado TLS e iniciar NGINX como proceso principal.

### Desglose del Script

```sh
#!/bin/sh
set -eu

: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
```

- `#!/bin/sh` — Usar shell POSIX (no bash, para portabilidad del contenedor)
- `set -eu` — Salir en error, error en variables indefinidas
- `: "${DOMAIN_NAME:?..."` — Requerir variable de entorno DOMAIN_NAME; salir si falta

### Verificación de Generación de Certificado

```sh
CERT_PATH="/etc/nginx/ssl/cert.pem"
KEY_PATH="/etc/nginx/ssl/key.pem"

if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$KEY_PATH" \
        -out "$CERT_PATH" \
        -subj "/CN=${DOMAIN_NAME}"
fi
```

**Patrón idempotente**:
- Verificar si certificado existe: `[ ! -f "$CERT_PATH" ]`
- Si falta → generar certificado y clave
- Si existe → omitir generación

**¿Por qué idempotente?**
- El contenedor podría reiniciarse sin que el volumen sea destruido
- Regenerar certificado cada reinicio fallaría si ya existe
- Init idempotente permite `docker compose restart` seguro

**Detalles del certificado**:
- `-x509 -nodes` → Autofirmado, sin frase de contraseña
- `-days 365` → Válido por 1 año desde fecha de generación
- `-newkey rsa:2048` → Generar clave privada (RSA 2048-bit es estándar moderno)
- `-subj "/CN=${DOMAIN_NAME}"` → Nombre Común establecido a dominio real (agarcia.42.fr)

### Sustitución de Nombre de Dominio

```sh
sed -i "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g" /etc/nginx/conf.d/default.conf
```

- Buscar y reemplazar marcador de posición `__DOMAIN_NAME__` con valor real
- `-i` → edición en el lugar (modificar archivo directamente)
- `g` → global (reemplazar todas las ocurrencias)

**Ejemplo**:
```nginx
# Antes (en Dockerfile):
server_name __DOMAIN_NAME__;

# Después (init.sh se ejecuta con DOMAIN_NAME=agarcia.42.fr):
server_name agarcia.42.fr;
```

**¿Por qué plantillas?**
- Los Dockerfiles son estáticos; no pueden acceder a variables de entorno en tiempo de ejecución
- init.sh se ejecuta en el contenedor con variables de entorno disponibles
- Plantilla + sed = configuración dinámica al iniciar

### Inicio de NGINX

```sh
exec nginx -g 'daemon off;'
```

- `exec` → Reemplazar proceso actual con nginx (init.sh sale, nginx se convierte en PID 1)
- `nginx -g 'daemon off;'` → Iniciar NGINX en primer plano
  - `-g` → Pasar directiva global
  - `daemon off` → No bifurcar a trasfondo (NGINX permanece como proceso principal)

**¿Por qué `exec` en lugar de ejecutar NGINX en trasfondo?**
- El init del contenedor debe usar PID 1 para el servicio principal
- Si init.sh sale, el contenedor muere (incluso si NGINX está corriendo)
- `exec` asegura que NGINX reemplace a init.sh como PID 1
- Las señales (SIGTERM) van directamente a NGINX, permitiendo cierre gracioso

---

## 5. Flujo de Inicio y Procesamiento de Solicitudes

### Secuencia de Inicio del Contenedor

```
1. Docker Compose inicia servicio nginx
   ↓
2. Punto de entrada: tini → /usr/local/bin/init.sh
   ↓
3. init.sh valida variable de entorno DOMAIN_NAME
   ↓
4. init.sh genera certificado TLS autofirmado (si falta)
   ↓
5. init.sh sustituye __DOMAIN_NAME__ en default.conf
   ↓
6. exec nginx -g 'daemon off;' inicia NGINX
   ↓
7. NGINX carga configuración desde /etc/nginx/nginx.conf
   ↓
8. NGINX incluye /etc/nginx/conf.d/*.conf (default.conf)
   ↓
9. NGINX escucha en puerto 443 (TLS) y espera solicitudes
```

### Procesamiento de Solicitud (Cliente → Respuesta)

```
Ejemplo: GET https://agarcia.42.fr/wp-admin/

1. NGINX recibe solicitud HTTPS en puerto 443
   ↓
2. Terminar TLS usando cert.pem/key.pem
   ↓
3. Verificar URI: /wp-admin/
   ↓
4. Coincidir bloques de ubicación:
   - location / → try_files: verificar archivo → verificar dir → pasar a /index.php
   - location ~ \.php$ → NO coincide (URI no es .php)
   ↓
5. Destino final: /index.php?args (URI no existe como archivo/dir)
   ↓
6. /index.php SÍ coincide con location ~ \.php$
   ↓
7. Reenviar a FastCGI: fastcgi_pass wordpress:9000
   ↓
8. PHP-FPM recibe solicitud, carga /var/www/html/index.php
   ↓
9. Código de WordPress se ejecuta, consulta MariaDB, genera HTML
   ↓
10. Respuesta HTML enviada de vuelta a través de FastCGI → NGINX
    ↓
11. NGINX encripta con TLS y envía al cliente
    ↓
12. Cliente recibe 200 OK con página de administrador de WordPress
```

### Ejemplo: Servicio de Archivo Estático

```
Ejemplo: GET https://agarcia.42.fr/wp-content/themes/style.css

1. NGINX recibe solicitud HTTPS
   ↓
2. Verificar bloques de ubicación:
   - location / → try_files: verificar archivo /wp-content/themes/style.css → EXISTE
   ↓
3. Servir archivo directamente (sin participación de PHP)
   ↓
4. Respuesta: 200 OK con contenido CSS + sendfile para eficiencia
```

**¿Por qué verificar archivo primero antes que PHP?**
- Activos estáticos servidos directamente por NGINX (rápido)
- Archivos .php reenviados a PHP-FPM (enrutamiento flexible)
- Patrón de alternativa asegura que el enrutamiento dinámico de WordPress funcione

---

## 6. Networking de Docker y Comunicación de Servicios

### Configuración de Red

```
Red puente de Docker: inception_net
├── nginx (puerto 443 expuesto al host)
├── wordpress (puerto 9000 interno, accesible como wordpress:9000 desde nginx)
└── mariadb (puerto 3306 interno, accesible como mariadb:3306 desde wordpress)
```

**Puntos clave**:
- NGINX ↔ WordPress: Comunicarse vía FastCGI en red Docker personalizada
- WordPress ↔ MariaDB: Comunicarse vía protocolo SQL en red Docker personalizada
- Solo puerto 443 de NGINX expuesto a máquina host
- Todos los servicios internos se comunican vía nombres DNS (nombres de servicios docker-compose)

### Resolución de DNS

```
fastcgi_pass wordpress:9000
```

- `wordpress` — Nombre de servicio en docker-compose.yml
- El resolvedor DNS de Docker resuelve automáticamente a IP del contenedor
- Sin necesidad de codificar direcciones IP (seguro para escalado)

---

## 7. Consideraciones de Seguridad

### Cifrado TLS

- ✅ Solo puerto 443 (sin HTTP 80)
- ✅ Mínimo TLS 1.2 (TLS 1.3 preferido)
- ✅ Cifrados fuertes (HIGH, sin MD5 ni autenticación anónima)
- ✅ Certificado autofirmado (suficiente para desarrollo/pruebas)

### Control de Acceso

- ✅ Archivos `.htaccess` bloqueados (deny all)
- ✅ Usuario www-data (proceso no-root)
- ✅ Sin listado de directorio (manejado por reescritura try_files)

### Potencial Endurecimiento (No Requerido para Checklist)

- Limitación de velocidad (`limit_req_zone`)
- Encabezados de seguridad (`add_header Strict-Transport-Security`)
- Integración ModSecurity WAF
- Compresión gzip para activos estáticos

---

## 8. Montaje de Volúmenes y Persistencia de Datos

### Acceso a Archivos de WordPress

```
NGINX sirve desde: /var/www/html
    ↓
Lo cual está montado en volumen nombrado de Docker: srcs_wp_data
    ↓
Lo cual se mapea a directorio host: /home/agarcia/data/wp_data
```

**Flujo de servicio de archivo**:
1. Cliente solicita `/wp-content/uploads/2024/image.jpg`
2. NGINX busca archivo en `/var/www/html/wp-content/uploads/2024/image.jpg`
3. Archivo existe en volumen (persistido de ejecuciones anteriores de WordPress)
4. Servir archivo directamente con sendfile

**Beneficio de persistencia**:
- `make fclean` and `make up` preserva imágenes cargadas
- Base de datos de WordPress permanece consistente con archivos cargados

---

## 9. Comandos de Testing y Validación

### Verificar Estado del Contenedor

```bash
docker compose ps
# Muestra: contenedor nginx UP en puerto 443

docker compose logs nginx
# Ver logs de inicio y errores
```

### Verificación Manual de Certificado TLS

```bash
curl -k -I https://agarcia.42.fr
# -k: ignorar advertencia de certificado autofirmado
# -I: solicitud HEAD (mostrar solo encabezados)
# Salida: HTTP/1.1 200 OK, versión TLS mostrada
```

### Verificar Sintaxis de Configuración

```bash
docker compose exec nginx nginx -t
# -t: probar sintaxis de archivo de configuración (sin inicio)
# Salida: "nginx: configuration file test is successful"
```

### Ver Logs de NGINX

```bash
docker compose logs nginx -f
# -f: seguir en tiempo real
# Muestra: access log (solicitudes GET) y error log
```

---

## 10. Estado de Cumplimiento: NGINX

| Requisito | Estado | Detalles |
|---|---|---|
| Imagen base | ✅ Aprobado | Debian:bullseye (no latest, conforme) |
| Sin nginx en WordPress | ✅ Aprobado | NGINX en contenedor separado |
| Solo puerto 443 | ✅ Aprobado | Solo 443 expuesto; puerto 80 no expuesto |
| Sin SSL/TLSv1.0 | ✅ Aprobado | TLSv1.2 TLSv1.3 aplicado |
| Certificado TLS | ✅ Aprobado | Autofirmado, generado al inicio |
| tini como PID 1 | ✅ Aprobado | Punto de entrada usa tini para manejo de señales |
| Init idempotente | ✅ Aprobado | Verificación de generación de certificado previene re-generación |
| Variables de entorno | ✅ Aprobado | DOMAIN_NAME usado correctamente |
| Sin bucles infinitos | ✅ Aprobado | Sin tail -f o while true |
| Proxy inverso | ✅ Aprobado | Reenvío FastCGI a WordPress configurado |

---

## 11. Resumen para Defensa

### ¿Qué es NGINX?
**Respuesta simple**: NGINX es la puerta de entrada que acepta conexiones HTTPS y las enruta a WordPress. También sirve archivos estáticos como imágenes y hojas de estilo directamente.

### ¿Por qué tres contenedores en lugar de uno?
Tres contenedores separados siguen mejores prácticas de Docker:
- **NGINX** (servidor web): Maneja todas las conexiones HTTP/HTTPS
- **WordPress** (servidor de aplicación): Ejecuta código PHP
- **MariaDB** (base de datos): Almacena todos los datos

Esta separación proporciona:
- **Escalabilidad**: Cada servicio puede actualizarse independientemente
- **Seguridad**: Cada uno se ejecuta como no-root con privilegios mínimos
- **Mantenibilidad**: Los cambios en uno no afectan a otros

### ¿Por qué TLS autofirmado?
- Para propósitos de aprendizaje/pruebas: certificados autofirmados son gratuitos y suficientes
- En el mundo real de producción: usa certificados de Let's Encrypt o CAs comerciales
- Requisito del checklist: HTTPS en 443 (sin HTTP desnudo)

### ¿Qué es FastCGI?
**Protocolo**: Método de comunicación NGINX ↔ PHP-FPM
- NGINX recibe solicitud HTTP en puerto 443
- NGINX convierte a FastCGI y envía a PHP-FPM en puerto 9000
- PHP-FPM ejecuta el código PHP, genera HTML
- HTML enviado de vuelta a través de FastCGI → NGINX

**¿Por qué no ejecutar PHP dentro de NGINX?**
- NGINX no ejecuta PHP nativamente (solo servidor web)
- PHP-FPM es un servidor de aplicación separado (ejecutor de PHP)
- FastCGI es el protocolo estándar entre ellos

### Decisiones Clave Tomadas

| Decisión | Razón |
|---|---|
| **HTTPS únicamente por defecto** | Cifrado obligatorio; sin alternativa a HTTP |
| **Certificado autofirmado** | Suficiente para desarrollo; auto-generado al inicio |
| **Regla de reescritura try_files** | Habilita URLs limpias de WordPress (/blog/post en lugar de /index.php?p=123) |
| **Nombre de servicio DNS en lugar de IP codificada** | Portátil; funciona incluso si las IPs del contenedor cambian |
| **Placeholders + sustitución sed** | Permite el mismo Dockerfile/config para diferentes dominios |
| **Generación de certificado idempotente** | Seguro reiniciar contenedor sin conflictos de certificado |

---

## 12. Resumen de Estado de Archivos

| Archivo | Estado | Propósito |
|---|---|---|
| `Dockerfile` | ✅ Usado | Construir imagen NGINX con tini, openssl, configuración |
| `conf/nginx.conf` | ✅ Usado | Configuración global: usuario, workers, política TLS, logging |
| `conf/default.conf` | ✅ Usado | Host virtual: puerto 443, TLS, reglas de reescritura, reenvío FastCGI |
| `tools/init.sh` | ✅ Usado | Generación de certificado, sustitución de dominio, inicio |

**Sin archivos legacy** — Todos los archivos de NGINX se usan activamente en la construcción final.

---

**Creado**: Abril 2026 | **Para**: Defensa del Proyecto Inception de la Escuela 42
