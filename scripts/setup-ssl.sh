#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-chenhh17.duckdns.org}"
EMAIL="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE_AVAIL="/etc/nginx/sites-available/controller.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/controller.conf"

if [[ "$DOMAIN" == *".github.io" ]]; then
  echo "ERROR: Let's Encrypt cannot issue certs for github.io on this VPS."
  echo "Use a domain you control whose A record points to this server."
  exit 1
fi

sudo mkdir -p /var/www/certbot
sudo mkdir -p /etc/letsencrypt

sed "s/DOMAIN_NAME/${DOMAIN}/g" "$ROOT/nginx/http-bootstrap.conf" | sudo tee "$SITE_AVAIL" >/dev/null
sudo ln -sfn "$SITE_AVAIL" "$SITE_ENABLED"
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

CERTBOT_ARGS=(certonly --webroot -w /var/www/certbot -d "$DOMAIN" --agree-tos --non-interactive --keep-until-expiring)
if [[ -n "$EMAIL" ]]; then
  CERTBOT_ARGS+=(--email "$EMAIL")
else
  CERTBOT_ARGS+=(--register-unsafely-without-email)
fi

sudo certbot "${CERTBOT_ARGS[@]}"

if [[ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]]; then
  sudo curl -fsSL https://raw.githubusercontent.com/certbot/certbot/v2.9.0/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
    -o /etc/letsencrypt/options-ssl-nginx.conf
fi
if [[ ! -f /etc/letsencrypt/ssl-dhparams.pem ]]; then
  sudo openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048
fi

sed "s/DOMAIN_NAME/${DOMAIN}/g" "$ROOT/nginx/ssl.conf" | sudo tee "$SITE_AVAIL" >/dev/null
sudo nginx -t
sudo systemctl reload nginx

sudo systemctl enable certbot.timer 2>/dev/null || true
sudo systemctl start certbot.timer 2>/dev/null || true

echo "HTTPS ready: https://${DOMAIN}/"
echo "Open TCP 443 in the cloud security group / firewall if needed."
