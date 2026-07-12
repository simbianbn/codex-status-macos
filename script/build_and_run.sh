#!/bin/zsh
set -euo pipefail

MODE="${1:-run}"
ROOT="${0:A:h:h}"
APP="$ROOT/dist/Codex Status.app"
EXECUTABLE="$APP/Contents/MacOS/CodexMenuBar"

pkill -x CodexMenuBar >/dev/null 2>&1 || true
"$ROOT/scripts/build-app.sh"

launch_app() {
    /usr/bin/open "$APP"
}

verify_single_instance() {
    local pid=""
    for _ in {1..30}; do
        pid=$(pgrep -f "$EXECUTABLE" | head -1 || true)
        [[ -n "$pid" ]] && break
        sleep 0.1
    done
    [[ -n "$pid" ]] || { echo "Codex Status did not launch" >&2; return 1; }
    sleep 1
    local count
    count=$(pgrep -f "$EXECUTABLE" | wc -l | tr -d ' ')
    [[ "$count" == "1" ]] || { echo "Expected 1 Codex Status instance, found $count" >&2; return 1; }
    echo "Codex Status running (pid $pid)"
}

case "$MODE" in
    run)
        launch_app
        ;;
    --debug|debug)
        lldb -- "$EXECUTABLE"
        ;;
    --logs|logs)
        launch_app
        /usr/bin/log stream --info --style compact --predicate 'process == "CodexMenuBar"'
        ;;
    --telemetry|telemetry)
        launch_app
        /usr/bin/log stream --info --style compact --predicate 'process == "CodexMenuBar"'
        ;;
    --verify|verify)
        launch_app
        verify_single_instance
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
