#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-chenhh17.cloud-ip.cc}"
EMAIL="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE_AVAIL="/etc/nginx/sites-available/controller.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/controller.conf"
STATE_DIR="/tmp/le-dns-${DOMAIN//\//_}"
AUTH_HOOK="$STATE_DIR/auth.sh"
CLEANUP_HOOK="$STATE_DIR/cleanup.sh"

rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
chmod 755 "$STATE_DIR"

cat >"$AUTH_HOOK" <<EOF
#!/usr/bin/env bash
set -euo pipefail
STATE_DIR="$STATE_DIR"
printf '%s\\n' "\$CERTBOT_VALIDATION" >"\$STATE_DIR/validation"
cat >"\$STATE_DIR/INSTRUCTIONS.txt" <<INSTR
Add this TXT record in ClouDNS:

Host: _acme-challenge
Type: TXT
Value: \$CERTBOT_VALIDATION
TTL: 1 minute (or 60)

Full name: _acme-challenge.$DOMAIN

Then on the server run:
  touch \$STATE_DIR/ready
INSTR
echo "Waiting for \$STATE_DIR/ready ..."
while [[ ! -f "\$STATE_DIR/ready" ]]; do
  sleep 2
done
echo "Checking TXT at 8.8.8.8 ..."
for _ in \$(seq 1 60); do
  if dig +short TXT "_acme-challenge.$DOMAIN" @8.8.8.8 | grep -Fq "\$CERTBOT_VALIDATION"; then
    echo "TXT visible"
    exit 0
  fi
  sleep 5
done
echo "WARNING: TXT not visible yet; continuing"
exit 0
EOF

cat >"$CLEANUP_HOOK" <<EOF
#!/usr/bin/env bash
set -euo pipefail
rm -f "$STATE_DIR/ready" "$STATE_DIR/validation" "$STATE_DIR/INSTRUCTIONS.txt" || true
exit 0
EOF

chmod 755 "$AUTH_HOOK" "$CLEANUP_HOOK"
sudo mkdir -p /etc/letsencrypt

CERTBOT_ARGS=(
  certonly
  --manual
  --preferred-challenges dns
  --manual-auth-hook "$AUTH_HOOK"
  --manual-cleanup-hook "$CLEANUP_HOOK"
  -d "$DOMAIN"
  --agree-tos
  --non-interactive
  --keep-until-expiring
)
if [[ -n "$EMAIL" ]]; then
  CERTBOT_ARGS+=(--email "$EMAIL")
else
  CERTBOT_ARGS+=(--register-unsafely-without-email)
fi

echo "Starting DNS-01 for ${DOMAIN}"
echo "Instructions will appear in: ${STATE_DIR}/INSTRUCTIONS.txt"

(
  while [[ ! -f "$STATE_DIR/INSTRUCTIONS.txt" ]]; do sleep 1; done
  echo
  cat "$STATE_DIR/INSTRUCTIONS.txt"
  echo
) &
PRINTER=$!

sudo certbot "${CERTBOT_ARGS[@]}"
kill "$PRINTER" 2>/dev/null || true

if [[ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]]; then
  sudo curl -fsSL https://raw.githubusercontent.com/certbot/certbot/v2.9.0/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
    -o /etc/letsencrypt/options-ssl-nginx.conf
fi
if [[ ! -f /etc/letsencrypt/ssl-dhparams.pem ]]; then
  sudo openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048
fi

sed "s/DOMAIN_NAME/${DOMAIN}/g" "$ROOT/nginx/ssl.conf" | sudo tee "$SITE_AVAIL" >/dev/null
sudo ln -sfn "$SITE_AVAIL" "$SITE_ENABLED"
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

sudo systemctl enable certbot.timer 2>/dev/null || true
sudo systemctl start certbot.timer 2>/dev/null || true

echo "HTTPS ready: https://${DOMAIN}/"
echo "You can delete the temporary TXT record in ClouDNS after this succeeds."
