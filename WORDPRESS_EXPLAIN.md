# WordPress explicado facil (Inception)

Este documento explica, paso a paso y en lenguaje simple, todos los archivos de WordPress que tienes en el proyecto.

## Mapa rapido

Carpeta: srcs/requirements/wordpress

Archivos detectados:
- Dockerfile
- conf/www.conf
- tools/init.sh
- tools/wp-config.php
- init.sh
- bash.sh

Importante:
- En tu build actual, el contenedor usa Dockerfile + conf/www.conf + tools/init.sh.
- tools/wp-config.php tampoco se usa en el flujo actual, porque wp-cli genera wp-config.php automaticamente.

## 1) Dockerfile
Archivo: srcs/requirements/wordpress/Dockerfile

Que hace:
1. FROM debian:bullseye
- Base del contenedor.

2. ENV DEBIAN_FRONTEND=noninteractive
- Evita preguntas interactivas al instalar paquetes.

3. RUN apt-get ...
- Instala:
  - php-fpm (motor PHP que atiende peticiones)
  - php-mysql (conexion a MariaDB)
  - mariadb-client (mysqladmin y cliente para comprobar DB)
  - curl, ca-certificates, less, unzip
  - tini (mini init, buen PID 1)
- Luego limpia cache apt para reducir tamano de imagen.

4. Instala wp-cli
- Descarga el binario de WP CLI como /usr/local/bin/wp.
- Le da permisos de ejecucion.

5. COPY conf/www.conf ...
- Copia configuracion de PHP-FPM pool.

6. COPY tools/init.sh ...
- Copia script de arranque que instala/configura WordPress.

7. RUN chmod +x ... + mkdir/chown
- Permite ejecutar init.sh.
- Prepara /run/php y /var/www/html.
- Da propiedad www-data a /var/www/html.

8. EXPOSE 9000
- Puerto interno para PHP-FPM.

9. ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/init.sh"]
- Arranque real: tini -> init.sh.

## 2) Configuracion PHP-FPM
Archivo: srcs/requirements/wordpress/conf/www.conf

Contenido y significado:
- [www]: pool principal.
- user/group = www-data: proceso PHP corre con usuario web.
- listen = 0.0.0.0:9000: escucha en TCP 9000 para NGINX.
- pm = dynamic y limites pm.*: control de procesos PHP.
- clear_env = no: conserva variables de entorno.

En simple:
- NGINX manda peticiones PHP a wordpress:9000.
- PHP-FPM las procesa aqui.

## 3) Script principal de arranque
Archivo: srcs/requirements/wordpress/tools/init.sh

Este es el archivo mas importante de WordPress.

### Paso A: validacion de variables
Comprueba que existan variables obligatorias:
- DB_NAME, DB_USER, DB_HOST
- DOMAIN_NAME
- datos admin de WP
- datos usuario autor de WP

Si falta algo critico, sale con error.

### Paso B: leer password DB
- Primero intenta DB_PASSWORD_FILE (Docker secret).
- Si no existe, usa DB_PWD.
- Si no hay ninguna, error y exit 1.

### Paso C: preparar carpeta web
- Crea /run/php y /var/www/html.
- Ajusta permisos a www-data.
- Entra a /var/www/html.

### Paso D: descargar WordPress si falta
- Si no existe wp-load.php, ejecuta:
  - wp core download --allow-root

Esto evita descargar de nuevo en cada reinicio.

### Paso E: crear wp-config.php si falta
- Si no existe wp-config.php, ejecuta wp config create con:
  - nombre DB
  - usuario DB
  - password DB
  - host DB

### Paso F: esperar MariaDB
- until mysqladmin ping -h"$DB_HOST" --silent; do sleep 2; done
- Espera hasta que MariaDB este listo antes de instalar WP.

### Paso G: instalar WordPress si aun no esta instalado
- wp core is-installed para comprobar estado.
- Si no esta instalado, ejecuta wp core install con:
  - URL (tu dominio)
  - titulo
  - usuario admin, password y email

### Paso H: crear segundo usuario (author)
- Si no existe, crea WP_USR con rol author.

### Paso I: arrancar PHP-FPM en foreground
- exec /usr/sbin/php-fpm7.4 -F
- Proceso principal del contenedor.

## 4) Plantilla tools/wp-config.php
Archivo: srcs/requirements/wordpress/tools/wp-config.php

Estado actual:
- Archivo presente, pero no usado por el Dockerfile ni por tools/init.sh.

Por que no se usa:
- Tu script usa wp config create para generar wp-config.php dinamico.

Recomendacion de defensa:
- Puedes decir que es un archivo legado de pruebas.
- Si quieres limpiar proyecto, se puede eliminar para evitar confusion.

## 5) Flujo real de arranque WordPress (resumen)
1. Arranca contenedor con tini.
2. Ejecuta tools/init.sh.
3. Valida variables y secretos.
4. Descarga/configura WordPress si falta.
5. Espera MariaDB.
6. Instala WordPress solo la primera vez.
7. Crea usuario author solo la primera vez.
8. Lanza php-fpm en primer plano.

## 6) Que explicar en defensa (30 segundos)
- WordPress corre en contenedor dedicado con PHP-FPM, sin nginx.
- NGINX en otro contenedor se conecta por FastCGI a wordpress:9000.
- init.sh es idempotente: solo descarga e instala cuando faltan archivos.
- Usa variables de entorno y secretos para credenciales.
- Espera a MariaDB antes de instalar para evitar fallos de carrera.

