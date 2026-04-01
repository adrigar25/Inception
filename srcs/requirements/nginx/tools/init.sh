#!/bin/sh
set -eu

: "${DOMAIN_NAME:?DOMAIN_NAME is required}"

CERT_PATH="/etc/nginx/ssl/cert.pem"
KEY_PATH="/etc/nginx/ssl/key.pem"

if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$KEY_PATH" \
        -out "$CERT_PATH" \
        -subj "/CN=${DOMAIN_NAME}"
fi

sed -i "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g" /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
