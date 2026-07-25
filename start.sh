#!/usr/bin/env bash
# Start ChoirMind web app + analysis backend together
# Usage: ./start.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB="$ROOT/web"
BACKEND="$ROOT/backend"

WEB_PID=""
BACKEND_PID=""

cleanup() {
  echo ""
  echo "Shutting down…"
  [ -n "$BACKEND_PID" ] && kill "$BACKEND_PID" 2>/dev/null || true
  [ -n "$WEB_PID" ] && kill "$WEB_PID" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [ ! -d "$WEB/node_modules" ]; then
  echo "Environment not set up yet. Run ./setup.sh first."
  exit 1
fi

echo "Starting ChoirMind…"
echo "  Web: http://localhost:3000"

if [ -d "$BACKEND/venv" ]; then
  echo "  Analysis: http://localhost:8000/docs  (API docs)"
  echo "            http://localhost:8000/health (health check)"
  (cd "$BACKEND" && source venv/bin/activate && uvicorn main:app --reload --host 127.0.0.1 --port 8000) &
  BACKEND_PID=$!
else
  echo "  Analysis: (skipped — run ./setup.sh with Python 3.10+ to enable)"
fi

echo "  Press Ctrl+C to stop"
echo ""

(cd "$WEB" && npm run dev) &
WEB_PID=$!

if [ -n "$BACKEND_PID" ]; then
  wait "$WEB_PID" "$BACKEND_PID"
else
  wait "$WEB_PID"
fi
