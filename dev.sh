#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_PACKAGE="$PROJECT_DIR/Frontend_Official.xcodeproj"
LOG_FILE="$PROJECT_DIR/backend.log"
PID_FILE="$PROJECT_DIR/backend.pid"

# ── Colours ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

info()  { echo -e "${GREEN}▶${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✖${NC}  $1"; exit 1; }

# ── Stop any existing backend ───────────────────────────────────────────────
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        warn "Stopping existing backend (PID $OLD_PID)…"
        kill "$OLD_PID"
        sleep 0.5
    fi
    rm -f "$PID_FILE"
fi

# Also free port 8000 if something else grabbed it
if lsof -ti :8000 &>/dev/null; then
    warn "Port 8000 in use — killing occupant…"
    kill "$(lsof -ti :8000)" 2>/dev/null || true
    sleep 0.5
fi

# ── Start backend ────────────────────────────────────────────────────────────
info "Starting backend…"
cd "$BACKEND_DIR"
uvicorn api:app --host 127.0.0.1 --port 8000 --reload > "$LOG_FILE" 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > "$PID_FILE"

# Wait for server to be ready (up to 10s)
info "Waiting for API server…"
for i in $(seq 1 20); do
    if curl -s http://127.0.0.1:8000/health | grep -q "ok"; then
        echo -e "${GREEN}✔${NC}  Backend ready at http://127.0.0.1:8000 (PID $BACKEND_PID)"
        break
    fi
    sleep 0.5
    if [ "$i" -eq 20 ]; then
        error "Backend failed to start. Check $LOG_FILE for details."
    fi
done

# ── Open frontend in Xcode ───────────────────────────────────────────────────
info "Opening frontend in Xcode…"
open "$FRONTEND_PACKAGE"

echo ""
echo -e "${GREEN}All systems go.${NC}"
echo "  Backend log : $LOG_FILE"
echo "  Stop server : kill \$(cat backend.pid)   or run ./dev.sh again to restart"
