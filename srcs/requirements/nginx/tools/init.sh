#!/bin/sh
set -eu

# Check required environment variables
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"

# Generate self-signed SSL certificate if not already present
CERT_PATH="/etc/nginx/ssl/cert.pem"
KEY_PATH="/etc/nginx/ssl/key.pem"

# Generate self-signed SSL certificate if not already present
if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$KEY_PATH" \
        -out "$CERT_PATH" \
        -subj "/CN=${DOMAIN_NAME}"
fi

# Replace placeholder in nginx configuration with actual domain name
sed -i "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g" /etc/nginx/conf.d/default.conf

# Start nginx in the foreground
exec nginx -g 'daemon off;'
