# Codex Quota Countdown and Menu Bar Logo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display a single Codex quota as `Codex: 99% (5d 4h)` and add a compact vector Codex Status logo to the menu bar capsule.

**Architecture:** Keep quota parsing in `CodexSessionParser`, deterministic countdown formatting in `StatusPresentation`, and AppKit drawing in `StatusCapsuleImage`. Pass the snapshot load time into presentation so tests do not depend on the wall clock.

**Tech Stack:** Swift 6, Foundation, AppKit, SwiftPM executable checks.

## Global Constraints

- Derive quota window names from `window_minutes`; do not assume `primary` is five hours.
- Derive countdowns from `resets_at` and an explicit current date.
- Keep the multi-window quota presentation intact.
- Draw the menu bar mark as a small vector; do not scale the 1024-pixel application icon.

---

### Task 1: Deterministic reset countdown presentation

**Files:**
- Modify: `Tests/CodexStatusCoreTests/main.swift`
- Modify: `Sources/CodexStatusCore/StatusPresentation.swift`
- Modify: `Sources/CodexStatusCore/CodexSessionParser.swift`

**Interfaces:**
- Consumes: `QuotaWindow.remainingPercent`, `QuotaWindow.resetsAt`, `CodexSnapshot.loadedAt`
- Produces: `StatusPresentation.menuBarQuotaText(mode:windows:now:) -> String`

- [ ] **Step 1: Add failing checks for countdown output**

Add checks covering `5d 4h`, `4h 30m`, `30m`, `resetting`, and missing reset time. Use fixed `Date` values and assert the single weekly window produces `Codex: 99% (5d 4h)`.

- [ ] **Step 2: Run the checks and confirm failure**

Run: `swift run CodexStatusTests`

Expected: the new countdown checks fail because the formatter still produces `7D 99%` and has no `now` parameter.

- [ ] **Step 3: Implement the minimal deterministic formatter**

Change the interface to:

```swift
public static func menuBarQuotaText(
    mode: MenuDisplayMode,
    windows: [QuotaWindow],
    now: Date
) -> String
```

For a single window in `.iconAndPercentage`, return `Codex: <percent>%` followed by a reset countdown when `resetsAt` exists. Floor elapsed components so the menu text does not jump upward. Retain percentage-only and multi-window behavior.

- [ ] **Step 4: Run the checks and confirm green**

Run: `swift run CodexStatusTests`

Expected: all checks pass, including the new countdown cases.

### Task 2: Draw the compact menu bar logo

**Files:**
- Modify: `Sources/CodexMenuBar/CodexMenuBarApp.swift`

**Interfaces:**
- Consumes: capsule foreground color and `StatusPresentation.menuBarQuotaText(mode:windows:now:)`
- Produces: a 14-point vector mark drawn before the activity dot and quota text

- [ ] **Step 1: Update the capsule presentation call**

Pass `snapshot.loadedAt` as `now` so every refresh updates the countdown.

- [ ] **Step 2: Add vector mark drawing**

Reserve 18 points for the mark. Draw a 12-point circular ring with a compact `C` centered inside it using the same foreground color as the text. Keep the activity dot after the mark and adjust text origin and total image width.

- [ ] **Step 3: Build and verify launch**

Run: `./script/build_and_run.sh --verify`

Expected: production build succeeds and `Codex Status` is running.

### Task 3: Regression and visual-surface verification

**Files:**
- Verify: `Sources/CodexStatusCore/CodexSessionParser.swift`
- Verify: `Sources/CodexStatusCore/StatusPresentation.swift`
- Verify: `Sources/CodexMenuBar/CodexMenuBarApp.swift`
- Verify: `Tests/CodexStatusCoreTests/main.swift`

- [ ] **Step 1: Run the full executable test suite**

Run: `swift run CodexStatusTests`

Expected: every check passes with zero failures.

- [ ] **Step 2: Verify the visible menu bar fallback surface**

Run: `./scripts/test-menubar-overlay.sh`

Expected: `PASS: visible capsule fallback window exists`.

- [ ] **Step 3: Check the final diff**

Run: `git diff --check && git status -sb`

Expected: no whitespace errors and only the intended parser, presentation, menu bar, test, spec, and plan changes are present.
