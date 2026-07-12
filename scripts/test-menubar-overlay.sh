#!/bin/zsh
set -euo pipefail

APP="${0:A:h:h}/dist/Codex Status.app"
pid=$(pgrep -f "$APP/Contents/MacOS/CodexMenuBar" | head -1 || true)
[[ -n "$pid" ]] || { echo "FAIL: Codex Status is not running"; exit 1; }

count=$(osascript <<APPLESCRIPT
tell application "System Events"
  tell first application process whose unix id is $pid
    return count of (every window whose title is "Codex Status Capsule")
  end tell
end tell
APPLESCRIPT
)

[[ "$count" == "1" ]] || { echo "FAIL: expected visible capsule fallback window, found $count"; exit 1; }
echo "PASS: visible capsule fallback window exists"
