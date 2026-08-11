#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="${1:-chenhh17.duckdns.org}"
SITE_AVAIL="/etc/nginx/sites-available/controller.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/controller.conf"

if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
  sed "s/DOMAIN_NAME/${DOMAIN}/g" "$ROOT/nginx/ssl.conf" | sudo tee "$SITE_AVAIL" >/dev/null
else
  sed "s/DOMAIN_NAME/${DOMAIN}/g" "$ROOT/nginx/http-bootstrap.conf" | sudo tee "$SITE_AVAIL" >/dev/null
fi

sudo ln -sfn "$SITE_AVAIL" "$SITE_ENABLED"
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
echo "nginx reloaded for ${DOMAIN}"
