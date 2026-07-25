#!/usr/bin/env bash
# ChoirMind one-shot environment setup
# Usage: ./setup.sh
# Optional: OPENAI_API_KEY=sk-... ./setup.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB="$ROOT/web"
BACKEND="$ROOT/backend"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}→${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}!${NC} $*"; }
fail()  { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

version_gte() {
  local current="$1" required="$2"
  [ "$(printf '%s\n' "$required" "$current" | sort -V | head -n1)" = "$required" ]
}

sed_inplace() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

write_env_file() {
  local dest="$1"
  if [ -f "$dest" ]; then
    warn "Keeping existing $(basename "$dest")"
    return
  fi
  cp "$WEB/.env.example" "$dest"
  ok "Created $(basename "$dest")"
}

set_openai_key_in_env() {
  local file="$1"
  local key="$2"
  if grep -q '^OPENAI_API_KEY=' "$file"; then
    sed_inplace "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=${key}|" "$file"
  else
    echo "OPENAI_API_KEY=${key}" >> "$file"
  fi
}

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     ChoirMind Environment Setup      ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Prerequisites ──────────────────────────────────────────────
info "Checking prerequisites…"

command -v node >/dev/null 2>&1 || fail "Node.js is required. Install from https://nodejs.org (18+)."
command -v npm  >/dev/null 2>&1 || fail "npm is required (comes with Node.js)."

NODE_VERSION="$(node -p "process.versions.node")"
version_gte "$NODE_VERSION" "18.0.0" || fail "Node.js 18+ required (found $NODE_VERSION)."
ok "Node.js $NODE_VERSION"

PYTHON=""
for candidate in python3.13 python3.12 python3.11 python3.10 python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PY_MAJOR="$("$candidate" -c 'import sys; print(sys.version_info.major)' 2>/dev/null || echo 0)"
    PY_MINOR="$("$candidate" -c 'import sys; print(sys.version_info.minor)' 2>/dev/null || echo 0)"
    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 10 ]; then
      PYTHON="$candidate"
      break
    fi
  fi
done

PY_VERSION=""
if [ -n "$PYTHON" ]; then
  PY_VERSION="$("$PYTHON" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
  ok "Python $PY_VERSION ($PYTHON)"
else
  warn "Python 3.10+ not found — skipping analysis backend (web app will still work)"
fi

# ── Environment files ──────────────────────────────────────────
info "Setting up environment files…"

[ -f "$WEB/.env.example" ] || fail "Missing $WEB/.env.example"

write_env_file "$WEB/.env"
write_env_file "$WEB/.env.local"

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo ""
  read -rsp "OpenAI API key (optional — press Enter to skip): " OPENAI_API_KEY || true
  echo ""
fi

if [ -n "${OPENAI_API_KEY:-}" ]; then
  set_openai_key_in_env "$WEB/.env" "$OPENAI_API_KEY"
  set_openai_key_in_env "$WEB/.env.local" "$OPENAI_API_KEY"
  ok "OpenAI API key saved to .env files"
else
  warn "No OpenAI API key — AI coach will use built-in rule-based feedback"
fi

# ── Web app ────────────────────────────────────────────────────
info "Installing web dependencies…"
(cd "$WEB" && npm install)
ok "npm packages installed"

info "Initializing database…"
(cd "$WEB" && npx prisma generate && npx prisma db push)
ok "Database schema applied"

info "Seeding demo data…"
(cd "$WEB" && npm run db:seed)
ok "Demo choir data seeded"

# ── Python backend ─────────────────────────────────────────────
if [ -n "$PYTHON" ]; then
  info "Setting up Python analysis backend…"

  VENV="$BACKEND/venv"
  if [ ! -d "$VENV" ]; then
    "$PYTHON" -m venv "$VENV"
    ok "Created Python virtual environment"
  else
    warn "Reusing existing backend/venv"
  fi

  # shellcheck disable=SC1091
  source "$VENV/bin/activate"
  python -m pip install --upgrade pip --quiet
  pip install -r "$BACKEND/requirements.txt" --quiet
  deactivate
  ok "Python dependencies installed"
else
  warn "Install Python 3.10+ and re-run ./setup.sh to enable the analysis backend"
fi

# ── Done ───────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Start the app:"
echo ""
echo "  Web (required):"
echo "    cd web && npm run dev"
echo "    → http://localhost:3000"
echo ""
echo "  Analysis backend (optional, enhanced pitch/rhythm):"
if [ -d "$BACKEND/venv" ]; then
  echo "    cd backend && source venv/bin/activate && uvicorn main:app --reload --port 8000"
  echo "    → http://localhost:8000/docs   (API docs)"
  echo "    → http://localhost:8000/health (health check)"
  echo ""
  echo "Or run both at once:"
  echo "    ./start.sh"
else
  echo "    (not installed — install Python 3.10+ and re-run ./setup.sh)"
fi
echo ""
