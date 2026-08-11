#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

sudo cp "$ROOT/nginx/http-bootstrap.conf" /etc/nginx/sites-available/controller.conf
sudo ln -sfn /etc/nginx/sites-available/controller.conf /etc/nginx/sites-enabled/controller.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
echo "nginx reloaded"
