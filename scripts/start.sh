#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/backend"

export PYTHONPATH="$ROOT/backend"
exec "$ROOT/backend/.venv/bin/gunicorn" \
  -b 127.0.0.1:9000 \
  -w 1 \
  --threads 2 \
  --timeout 60 \
  --access-logfile - \
  --error-logfile - \
  wsgi:app
