#!/bin/sh
# Первый сертификат Let's Encrypt для домена прокси и подстановка домена в
# конфиг внешнего слоя. Запускать один раз: ./init-certificate.sh proxy.example.org
set -eu
domain="${1:-}"
if [ -z "$domain" ]; then
  echo "usage: $0 <domain>" >&2
  exit 1
fi
sed -i.bak "s#/etc/letsencrypt/live/[^/]*/#/etc/letsencrypt/live/$domain/#g" nginx-terminate/nginx.conf
mkdir -p data/certbot/conf data/certbot/www
docker run --rm -p 80:80 \
  -v "$(pwd)/data/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/data/certbot/www:/var/www/certbot" \
  certbot/certbot certonly --standalone --non-interactive --agree-tos \
  --register-unsafely-without-email -d "$domain"
echo "Certificate ready. Now: docker compose up -d"
echo "Share with people: secretly://proxy#$domain"
