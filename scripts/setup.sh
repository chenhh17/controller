#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 -m venv "$ROOT/backend/.venv"
"$ROOT/backend/.venv/bin/pip" install --upgrade pip
"$ROOT/backend/.venv/bin/pip" install -r "$ROOT/backend/requirements.txt"

cd "$ROOT/frontend"
npm install
NODE_OPTIONS=--max-old-space-size=384 npm run build

chmod o+x "$HOME" 2>/dev/null || true
echo "Setup complete."
