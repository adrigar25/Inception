# Guía Completa de Dockerfiles

## ¿Qué es un Dockerfile?

Un Dockerfile es un archivo de texto que contiene un conjunto de instrucciones para crear una imagen Docker. Es como una "receta" que le dice a Docker cómo construir una imagen paso a paso.

---

## Estructura Básica de un Dockerfile

```dockerfile
FROM ubuntu:20.04
RUN apt-get update
COPY ./app /app
WORKDIR /app
EXPOSE 8080
CMD ["./start.sh"]
```

---

## Instrucciones Principales

### 1. **FROM** (Obligatoria)
Define la imagen base sobre la cual se construirá tu imagen.

```dockerfile
FROM ubuntu:20.04
FROM python:3.9
FROM nginx:latest
FROM centos:7
```

**Características:**
- Es la primera instrucción que DEBE aparecer en un Dockerfile
- Define el sistema operativo base y librerías fundamentales
- Si usas `FROM scratch`, creas una imagen vacía desde cero

**Ejemplos en tu proyecto:**
```dockerfile
# nginx/Dockerfile
FROM debian:bullseye
# mariadb/Dockerfile
FROM debian:bullseye
# wordpress/Dockerfile
FROM debian:bullseye
```

---

### 2. **RUN**
Ejecuta comandos dentro del contenedor durante la construcción.

```dockerfile
RUN apt-get update
RUN apt-get install -y nginx
RUN echo "Hello World" > /tmp/hello.txt
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git
```

**Características:**
- Se ejecuta en tiempo de **construcción** (build time)
- Crea capas (layers) en la imagen
- La forma correcta es usar `&&` para encadenar comandos
- Usa backslash `\` para dividir comandos largos

**Buenas prácticas:**
```dockerfile
# ❌ MALO - Crea muchas capas
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y wget

# ✅ BUENO - Una sola capa
RUN apt-get update && apt-get install -y \
    curl \
    wget
```

---

### 3. **COPY**
Copia archivos desde tu máquina host hacia el contenedor.

```dockerfile
COPY ./archivo.txt /app/archivo.txt
COPY ./src /app/src
COPY --chown=user:user ./archivo.txt /app/
```

**Características:**
- Copia archivos del **contexto de build** (donde está el Dockerfile)
- Propietario por defecto es `root:root`
- Puede usar wildcards: `COPY *.txt /app/`
- Opción `--chown` para establecer propietario

**Tipos de sintaxis:**
```dockerfile
# Sintaxis clásica
COPY origen destino

# Con --chown (cambiar propietario)
COPY --chown=www-data:www-data ./conf /etc/nginx/

# Copiar directorio completo
COPY ./src /app/src
```

---

### 4. **ADD** (Alternativa a COPY)
Similar a COPY, pero con funcionalidades adicionales.

```dockerfile
ADD ./app.tar.gz /app/
ADD https://example.com/file.zip /app/
```

**Diferencias con COPY:**
- Puede descomprimir archivos `.tar`
- Puede descargar archivos desde URLs
- **Recomendación:** Usa COPY cuando sea posible (más predecible)

---

### 5. **WORKDIR**
Establece el directorio de trabajo dentro del contenedor.

```dockerfile
WORKDIR /app
RUN npm install
COPY . .
CMD ["npm", "start"]
```

**Características:**
- Todos los comandos posteriores se ejecutan en este directorio
- Si no existe, se crea automáticamente
- Reemplaza el uso de `cd` en RUN

**Equivalente en terminal:**
```bash
cd /app
```

---

### 6. **EXPOSE**
Documenta qué puertos el contenedor escucha.

```dockerfile
EXPOSE 80
EXPOSE 443
EXPOSE 3306
EXPOSE 8080
```

**Características:**
- **NO expone realmente los puertos** (solo documenta)
- Debes mapear puertos con `-p` en `docker run`
- Es información para otros desarrolladores
- Puede especificar protocolo: `EXPOSE 8080/udp`

**Ejemplo de uso:**
```bash
# El EXPOSE es informativo
docker run -p 8080:8080 mi-imagen
```

---

### 7. **ENV**
Define variables de entorno dentro del contenedor.

```dockerfile
ENV NODE_ENV=production
ENV DATABASE_URL=localhost
ENV PORT=3000
```

**Características:**
- Las variables están disponibles en tiempo de ejecución
- Se pueden anular con `docker run -e`
- Afectan a todos los procesos del contenedor

**Ejemplo:**
```dockerfile
ENV MYSQL_ROOT_PASSWORD=secreto
ENV MYSQL_DATABASE=wordpress
```

---

### 8. **ARG**
Define argumentos que se pueden pasar durante la construcción.

```dockerfile
ARG VERSION=1.0
ARG BUILD_DATE

RUN echo "Construyendo versión ${VERSION}"
```

**Diferencia con ENV:**
- ARG: Solo disponible durante la construcción
- ENV: Disponible en el contenedor en ejecución

**Uso en build:**
```bash
docker build --build-arg VERSION=2.0 .
```

---

### 9. **USER**
Especifica el usuario que ejecutará los comandos.

```dockerfile
RUN useradd -m appuser
USER appuser
CMD ["./app"]
```

**Características:**
- Por defecto es `root` (peligro de seguridad)
- Puede cambiar con `USER nombre` o `USER UID:GID`
- Los comandos posteriores se ejecutan con este usuario

**Buena práctica:**
```dockerfile
# Crear usuario no-root
RUN useradd -m -u 1000 appuser
USER appuser
CMD ["./app"]
```

---

### 10. **CMD**
Define el comando por defecto cuando se inicia el contenedor.

```dockerfile
CMD ["./start.sh"]
CMD ["python", "app.py"]
CMD ["nginx", "-g", "daemon off;"]
```

**Formas de sintaxis:**
```dockerfile
# Sintaxis exec (recomendada) - directamente ejecutable
CMD ["executable", "param1", "param2"]

# Sintaxis shell
CMD command param1 param2
```

**Características:**
- Se puede anular con `docker run comando`
- Solo puede haber una instrucción CMD por Dockerfile
- Si hay múltiples, la última prevalece

---

### 11. **ENTRYPOINT**
Define el punto de entrada del contenedor (comando que siempre se ejecuta).

```dockerfile
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["start"]
```

**Diferencia con CMD:**
- ENTRYPOINT: comando que siempre se ejecuta
- CMD: argumento por defecto para ENTRYPOINT

**Ejemplo práctico:**
```dockerfile
ENTRYPOINT ["echo"]
CMD ["Hola"]

# docker run imagen            → imprime "Hola"
# docker run imagen "Adiós"    → imprime "Adiós"
```

---

### 12. **VOLUME**
Define puntos de montaje para persistencia de datos.

```dockerfile
VOLUME ["/data"]
VOLUME ["/var/log/nginx", "/var/www/html"]
```

**Características:**
- Crea un volumen que los contenedores pueden usar
- Los datos persisten aunque el contenedor se elimine
- Se usa principalmente con `docker-compose`

---

### 13. **HEALTHCHECK**
Define cómo verificar si el contenedor está saludable.

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1
```

**Parámetros:**
- `--interval`: frecuencia de comprobación (default 30s)
- `--timeout`: tiempo máximo espera (default 30s)
- `--start-period`: tiempo antes de empezar comprobaciones (default 0s)
- `--retries`: fallos antes de marcar como unhealthy (default 3)

---

### 14. **LABEL**
Añade metadatos a la imagen.

```dockerfile
LABEL version="1.0"
LABEL description="Aplicación web"
LABEL maintainer="usuario@example.com"
```

---

### 15. **STOPSIGNAL**
Especifica qué señal enviar para detener el contenedor.

```dockerfile
STOPSIGNAL SIGTERM
```

---

## Orden Recomendado en un Dockerfile

```dockerfile
FROM ubuntu:20.04

# Metadatos
LABEL maintainer="email@example.com"
LABEL description="Mi aplicación"

# Variables de entorno
ENV NODE_ENV=production
ENV PORT=3000

# Argumentos de construcción
ARG BUILD_DATE

# Sistema de archivos (crear directorios, descargar dependencias)
RUN apt-get update && apt-get install -y \
    curl \
    wget

# Copiar archivos de aplicación
COPY ./app /app
COPY ./config /etc/app/

# Directorio de trabajo
WORKDIR /app

# Crear usuario no-root
RUN useradd -m appuser
USER appuser

# Exponer puertos
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s CMD curl -f http://localhost:3000/health

# Punto de entrada
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["start"]
```

---

## Ejemplo Completo: Dockerfile para Nginx

```dockerfile
FROM debian:bullseye

# Instalación de dependencias
RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar configuración
COPY ./conf/nginx.conf /etc/nginx/nginx.conf
COPY ./conf/default.conf /etc/nginx/sites-available/default

# Crear directorios
RUN mkdir -p /var/www/html

# Exponer puerto
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s CMD curl -f http://localhost/ || exit 1

# Comando de inicio
CMD ["nginx", "-g", "daemon off;"]
```

---

## Mejores Prácticas

### 1. **Minimizar capas**
```dockerfile
# ❌ MALO - muchas capas
RUN apt-get update
RUN apt-get install -y nginx
RUN echo "test" > /tmp/test

# ✅ BUENO - pocas capas
RUN apt-get update && apt-get install -y nginx && echo "test" > /tmp/test
```

### 2. **Usar imágenes base ligeras**
```dockerfile
# ❌ Pesado (900 MB)
FROM ubuntu:20.04

# ✅ Ligero (150 MB)
FROM debian:bullseye-slim

# ✅ Muy ligero (10 MB)
FROM alpine:latest
```

### 3. **Limpiar después de instalar**
```dockerfile
RUN apt-get update && apt-get install -y \
    nginx \
    && rm -rf /var/lib/apt/lists/*  # Eliminar caché
```

### 4. **No construir como root**
```dockerfile
RUN useradd -m appuser
USER appuser
```

### 5. **Usar .dockerignore**
Crea archivo `.dockerignore` en la raíz del proyecto:
```
node_modules
.git
.env
*.log
```

### 6. **Multi-stage builds** (para producción)
```dockerfile
# Stage 1: Build
FROM node:14 AS builder
WORKDIR /app
COPY . .
RUN npm install && npm run build

# Stage 2: Runtime
FROM node:14-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/index.js"]
```

---

## Comandos Relacionados

```bash
# Construir una imagen
docker build -t nombre:tag .

# Construir con argumentos
docker build --build-arg VERSION=2.0 -t nombre:tag .

# Listar imágenes
docker images

# Ver historial de capas
docker history nombre:tag

# Eliminar imagen
docker rmi nombre:tag
```

---

## Resumen de Instrucciones

| Instrucción | Propósito | Tiempo |
|---|---|---|
| FROM | Imagen base | Build |
| RUN | Ejecutar comando | Build |
| COPY | Copiar archivos | Build |
| ADD | Copiar + decomprimir | Build |
| WORKDIR | Directorio trabajo | Build |
| ENV | Variable entorno | Runtime |
| ARG | Argumento build | Build |
| EXPOSE | Documentar puerto | Metadata |
| USER | Usuario ejecución | Runtime |
| CMD | Comando por defecto | Runtime |
| ENTRYPOINT | Punto entrada | Runtime |
| VOLUME | Punto montaje | Metadata |
| HEALTHCHECK | Verificar salud | Runtime |
| LABEL | Metadatos | Metadata |

