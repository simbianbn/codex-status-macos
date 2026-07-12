# Codex Status Settings, Login, and Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a recognizable app icon, a native Settings window, safe Codex account detection, and an official Codex login launcher to the existing menu bar app.

**Architecture:** `CodexAccountProvider` reads only non-secret auth metadata and launches the installed Codex login command. `AppPreferences` persists validated display/general options; the AppKit shell owns a reusable SwiftUI Settings window and renders a compact status image from the current preferences.

**Tech Stack:** Swift 6, SwiftUI, AppKit, ServiceManagement, Foundation, SwiftPM, executable test runner, ImageMagick/iconutil build tooling

## Global Constraints

- Target macOS 13 or newer.
- Never decode, display, log, or copy token, API key, password, or credential values.
- Login must use the official installed Codex flow; the app never implements OAuth.
- Preferences live in UserDefaults and contain no secrets.
- Preserve one-process launch behavior and the compact notch-safe menu item.
- Use TDD with the existing `CodexStatusTests` executable runner.

---

### Task 1: Account status and safe login launcher

**Files:**
- Create: `Sources/CodexStatusCore/CodexAccountProvider.swift`
- Modify: `Tests/CodexStatusCoreTests/main.swift`

**Interfaces:**
- Produces: `AccountState`, `AccountSnapshot`, `CodexAccountProvider.loadStatus()`, `CodexAccountProvider.loginCommand(executable:)`.

- [ ] **Step 1: Add failing checks**

Add fixtures containing a harmless `auth_mode` plus fake credential keys and assert only login state/plan are returned; missing/malformed files must map to signed-out/unavailable.

```swift
tests.expect(provider.parse(#"{"auth_mode":"chatgpt","tokens":{"access_token":"SECRET"}}"#).state == .signedIn, "detects ChatGPT auth without exposing token")
tests.expect(provider.parse("{}").state == .signedOut, "empty auth is signed out")
```

- [ ] **Step 2: Verify RED**

Run: `swift run CodexStatusTests`
Expected: compile failure because `CodexAccountProvider` is missing.

- [ ] **Step 3: Implement minimal provider**

Decode only allowlisted top-level keys with `JSONSerialization`, never copy nested credential dictionaries, and return a launch specification for `/usr/bin/env codex login` only after resolving a `codex` executable.

- [ ] **Step 4: Verify GREEN and commit**

Run: `swift run CodexStatusTests`
Expected: all existing and account checks pass.

```bash
git add Sources/CodexStatusCore/CodexAccountProvider.swift Tests/CodexStatusCoreTests/main.swift
git commit -m "feat: detect Codex account safely"
```

### Task 2: Preferences and menu presentation

**Files:**
- Create: `Sources/CodexStatusCore/AppPreferences.swift`
- Modify: `Sources/CodexStatusCore/StatusPresentation.swift`
- Modify: `Tests/CodexStatusCoreTests/main.swift`

**Interfaces:**
- Produces: `MenuDisplayMode`, `PreferenceValues`, `PreferenceStore`, and compact presentation helpers.

- [ ] **Step 1: Add failing checks**

Test defaults, refresh intervals 15/30/60, critical threshold clamping to 5...40, and strings for icon+percentage/percentage/icon modes.

```swift
tests.expect(PreferenceValues(criticalThreshold: 99).criticalThreshold == 40, "clamps critical threshold")
tests.expect(StatusPresentation.compactText(mode: .percentageOnly, remainingPercent: 72) == "72%", "percentage mode")
```

- [ ] **Step 2: Verify RED, implement, and verify GREEN**

Run before and after: `swift run CodexStatusTests`
Expected before: missing preference types; after: all checks pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodexStatusCore/AppPreferences.swift Sources/CodexStatusCore/StatusPresentation.swift Tests/CodexStatusCoreTests/main.swift
git commit -m "feat: add Codex Status preferences"
```

### Task 3: Settings window and account actions

**Files:**
- Create: `Sources/CodexMenuBar/SettingsView.swift`
- Create: `Sources/CodexMenuBar/SettingsWindowController.swift`
- Create: `Sources/CodexMenuBar/AccountStore.swift`
- Modify: `Sources/CodexMenuBar/CodexMenuBarApp.swift`
- Modify: `Sources/CodexMenuBar/StatusPopover.swift`
- Modify: `Sources/CodexMenuBar/StatusStore.swift`

**Interfaces:**
- Consumes: account provider and preference store from Tasks 1–2.
- Produces: reusable Settings window, login/open-Codex actions, configurable timer, account row in popover.

- [ ] **Step 1: Implement Settings window shell**

Use one retained `SettingsWindowController` with `NSHostingController(rootView:)`; reuse and focus the same window on repeated opens.

- [ ] **Step 2: Implement three Settings sections**

Account shows status and safe actions; Display binds mode/color/threshold/activity; General binds refresh interval, launch-at-login through `SMAppService`, data path, version, and data refresh.

- [ ] **Step 3: Integrate AppKit actions and popover gear**

Add `เปิดการตั้งค่า` and account status to the popover. Login launches the resolved official command in Terminal and polls account state without reading command output.

- [ ] **Step 4: Build verification and commit**

Run: `swift build && swift run CodexStatusTests`
Expected: build succeeds and all checks pass.

```bash
git add Sources/CodexMenuBar
git commit -m "feat: add settings and Codex login flow"
```

### Task 4: Icon and bundle integration

**Files:**
- Create: `assets/AppIcon-master.png`
- Create: `assets/AppIcon.icns`
- Modify: `scripts/build-app.sh`
- Modify: `script/build_and_run.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: generated icon asset.
- Produces: icon-bearing `dist/Codex Status.app` with single-instance verified launch.

- [ ] **Step 1: Generate and inspect icon**

Generate a dark macOS squircle with a white C and green/cyan gauge ring, then inspect the master at full size and 16px preview for legibility.

- [ ] **Step 2: Build ICNS and bundle it**

Create the iconset sizes, run `iconutil`, copy `AppIcon.icns` into `Contents/Resources`, and set `CFBundleIconFile=AppIcon` plus `NSPrincipalClass=NSApplication`.

- [ ] **Step 3: Full verification**

Run: `swift run CodexStatusTests && swift build && ./script/build_and_run.sh --verify && ./scripts/test-launch.sh`
Expected: all checks pass, bundle builds, exactly one process remains, and app icon resource exists.

- [ ] **Step 4: Commit**

```bash
git add assets scripts script README.md
git commit -m "feat: add Codex Status app icon"
```

