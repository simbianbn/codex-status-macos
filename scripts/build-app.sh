#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/Codex Status.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

cd "$ROOT"
swift build -c release --product CodexMenuBar
rm -rf "$APP"
mkdir -p "$MACOS"
cp ".build/release/CodexMenuBar" "$MACOS/CodexMenuBar"

plutil -create xml1 "$CONTENTS/Info.plist"
plutil -insert CFBundleName -string "Codex Status" "$CONTENTS/Info.plist"
plutil -insert CFBundleDisplayName -string "Codex Status" "$CONTENTS/Info.plist"
plutil -insert CFBundleIdentifier -string "local.codex.statusbar" "$CONTENTS/Info.plist"
plutil -insert CFBundleExecutable -string "CodexMenuBar" "$CONTENTS/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "$CONTENTS/Info.plist"
plutil -insert CFBundleShortVersionString -string "1.0.0" "$CONTENTS/Info.plist"
plutil -insert CFBundleVersion -string "1" "$CONTENTS/Info.plist"
plutil -insert LSMinimumSystemVersion -string "13.0" "$CONTENTS/Info.plist"
plutil -insert LSUIElement -bool true "$CONTENTS/Info.plist"
codesign --force --deep --sign - "$APP"
echo "$APP"
