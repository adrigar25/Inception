# MariaDB explicado fácil (Inception)

Este documento resume, en lenguaje simple, qué hace cada parte de MariaDB en tu proyecto.

## 1) Dockerfile de MariaDB
Archivo: srcs/requirements/mariadb/Dockerfile

### Línea a línea
1. `FROM debian:bullseye`
- Base del contenedor.

2. `RUN apt-get ... mariadb-server tini ...`
- Instala MariaDB.
- Instala `tini` (mini-init para manejar bien señales y procesos hijos).
- Limpia caché de apt para reducir tamaño de imagen.

3. `COPY conf/50-server.cnf ...`
- Copia la configuración del servidor MariaDB.

4. `COPY tools/init.sh ...`
- Copia el script que inicializa la base de datos al arrancar.

5. `RUN chmod +x ...`
- Da permisos de ejecución al script.

6. `EXPOSE 3306`
- Puerto típico de MariaDB.

7. `ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/init.sh"]`
- Arranque real del contenedor: primero `tini`, luego `init.sh`.

## 2) Configuración MariaDB
Archivo: srcs/requirements/mariadb/conf/50-server.cnf

Contenido:
- `[mysqld]`
- `bind-address=0.0.0.0`

Significa:
- MariaDB escucha en todas las interfaces del contenedor.
- Permite que WordPress (en otro contenedor de la red Docker) se conecte.

## 3) init.sh de MariaDB (paso a paso)
Archivo: srcs/requirements/mariadb/tools/init.sh

## Bloque A: modo seguro y variables obligatorias
- `set -eu`
  - `-e`: si algo falla, el script se corta.
  - `-u`: si falta una variable, da error.
- Exige `DB_NAME` y `DB_USER`.

## Bloque B: leer secretos (passwords)
Hace 2 bloques parecidos porque son 2 contraseñas distintas:
- Contraseña root (`DB_ROOT_PASSWORD_FILE` o `DB_ROOT_PWD`).
- Contraseña del usuario de app (`DB_PASSWORD_FILE` o `DB_PWD`).

Orden de prioridad:
1. Primero desde archivo (Docker secrets).
2. Si no existe, desde variable env.
3. Si no hay ninguna, error y sale.

## Bloque C: preparar carpetas
- Crea `/run/mysqld` y `/var/lib/mysql`.
- Ajusta propietario a `mysql:mysql`.

## Bloque D: marcador de inicialización
- `INIT_MARKER=/var/lib/mysql/.inception_initialized`
- Si NO existe, se hace inicialización de primera vez.
- Si existe, salta setup y arranca directo MariaDB.

Esto evita repetir creación de usuarios/DB en cada reinicio.

## Bloque E: primera inicialización (solo una vez)
1. `mariadb-install-db --user=mysql --datadir=/var/lib/mysql`
- Crea tablas internas del sistema si faltan.

2. Arranca mysqld temporal:
- `mysqld --skip-networking --socket=... &`
- `--skip-networking`: sin red, solo local (más seguro en setup).
- `--socket=/run/mysqld/mysqld.sock`: conexión local por socket.

3. Espera a que esté listo:
- `mysqladmin ... ping --silent`
- Repite hasta que MariaDB responda.

4. Ejecuta SQL inicial con heredoc:
- `mysql --socket=... <<EOF ... EOF`
- Todo lo que hay entre `EOF` son comandos SQL.

### SQL explicado muy simple
```sql
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_ROOT_PASSWORD}');
CREATE DATABASE IF NOT EXISTS `${DB_NAME}`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON `${DB_NAME}`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
```

Qué hace:
1. Pone/actualiza password de root local.
2. Crea la base de datos de WordPress.
3. Crea el usuario de aplicación (si no existe).
4. Le da permisos completos sobre esa base de datos.
5. Aplica permisos inmediatamente.

5. Apaga instancia temporal y crea marcador:
- `kill` + `wait` del proceso temporal.
- `touch /var/lib/mysql/.inception_initialized`.

## Bloque F: arranque final
- `exec mysqld --user=mysql --console`
- Arranca MariaDB normal en primer plano (proceso principal del contenedor).

## 4) Qué es socket (muy corto)
Un socket aquí es un "canal local" dentro del contenedor para hablar con MariaDB sin usar red TCP.

- Socket: `/run/mysqld/mysqld.sock`
- Sirve para setup interno seguro.
- WordPress luego conecta por red Docker (host `mariadb`, puerto 3306).

## 5) Resumen de defensa (30 segundos)
- El contenedor arranca con `tini` + `init.sh`.
- `init.sh` valida variables y secretos.
- En primer arranque crea estructura de MariaDB, levanta instancia temporal local por socket, configura root/DB/user, marca inicialización y apaga temporal.
- Después siempre arranca mysqld normal.
- Esto hace el proceso idempotente, seguro y persistente con volumen.
