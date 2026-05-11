#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/backend"

PORT="${PORT:-3000}"
HOST="${HOST:-0.0.0.0}"
MODE="${MODE:-prod}"

cleanup_port() {
    local pids=$(lsof -ti ":$1" 2>/dev/null || true)
    for pid in $pids; do
        [[ "$pid" != "$$" && "$pid" != "$PPID" ]] && kill -15 "$pid" 2>/dev/null || true
    done
    sleep 1
}

cleanup_port "$PORT"

if [ "$MODE" = "dev" ]; then
    export CORS_ALLOW_ORIGIN="http://localhost:5173;http://localhost:${PORT}"

    # Start frontend Vite dev server in background
    echo "Starting frontend dev server on http://localhost:5173 ..."
    cd "$SCRIPT_DIR"
    npm run dev -- --host --port 5173 &
    VITE_PID=$!
    cd "$SCRIPT_DIR/backend"

    # Clean up Vite when backend exits
    trap "kill $VITE_PID 2>/dev/null" EXIT

    "$SCRIPT_DIR/.venv/bin/python" -m uvicorn open_webui.main:app \
        --host "$HOST" --port "$PORT" --reload --ws auto
else
    exec "$SCRIPT_DIR/.venv/bin/python" -m uvicorn open_webui.main:app \
        --host "$HOST" --port "$PORT" --workers "${UVICORN_WORKERS:-1}" --ws auto
fi
