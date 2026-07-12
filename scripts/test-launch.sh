#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/Codex Status.app"

open -n "$APP"
pid=""
for _ in {1..20}; do
    pid=$(pgrep -f "$APP/Contents/MacOS/CodexMenuBar" | head -1 || true)
    [[ -n "$pid" ]] && break
    sleep 0.1
done

if [[ -z "$pid" ]]; then
    echo "FAIL: app did not launch"
    exit 1
fi

sleep 2
if ! kill -0 "$pid" 2>/dev/null; then
    echo "FAIL: app exited during launch"
    exit 1
fi

echo "PASS: app remains active (pid $pid)"
