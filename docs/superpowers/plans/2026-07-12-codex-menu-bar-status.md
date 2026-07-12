# Codex Menu Bar Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS Menu Bar app that displays verified local Codex quota and current task activity in a compact colored capsule and detail popover.

**Architecture:** A SwiftPM executable owns the SwiftUI `MenuBarExtra`. A reusable `CodexStatusCore` library parses only rate-limit and task-event metadata from local Codex JSONL session files, while a `StatusStore` periodically selects the newest records and supplies immutable view state to the UI.

**Tech Stack:** Swift 6, SwiftUI, Foundation, Swift Package Manager, XCTest

## Global Constraints

- Target macOS 13 or newer because `MenuBarExtra` is required.
- Read Codex data only from `~/.codex/sessions/**/*.jsonl`; never modify it.
- Never parse, display, log, or persist prompt, response, API key, or credential content.
- Refresh every 30 seconds and immediately when the app starts or the user presses refresh.
- Show `Codex —` instead of estimating quota when no verified `used_percent` exists.
- Interpret remaining quota as `100 - used_percent`, clamped to `0...100`.
- Use the more constrained verified window (lowest remaining percentage) for the capsule.

---

### Task 1: Package and quota domain

**Files:**
- Create: `Package.swift`
- Create: `Sources/CodexStatusCore/StatusModels.swift`
- Create: `Sources/CodexStatusCore/CodexSessionParser.swift`
- Create: `Tests/CodexStatusCoreTests/CodexSessionParserTests.swift`

**Interfaces:**
- Produces: `QuotaWindow`, `QuotaSnapshot`, `TaskActivity`, `CodexSnapshot`, `QuotaTone`, and `CodexSessionParser.parse(lines:now:)`.

- [ ] **Step 1: Write failing parser and threshold tests**

Create XCTest cases with synthetic JSONL lines containing `event_msg/token_count/rate_limits`, checking `remainingPercent`, reset timestamps, unknown usage, and tone boundaries at 19, 20, 50, and 51 percent.

```swift
func testParsesMostConstrainedQuotaWindow() throws {
    let line = #"{"timestamp":"2026-07-12T10:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_name":"Codex","primary":{"used_percent":25,"window_minutes":300,"resets_at":1783854000},"secondary":{"used_percent":60,"window_minutes":10080,"resets_at":1784458800}}}}"#
    let result = CodexSessionParser().parse(lines: [line], now: Date(timeIntervalSince1970: 1_783_850_000))
    XCTAssertEqual(result.quota?.remainingPercent, 40)
    XCTAssertEqual(result.quota?.tone, .warning)
}
```

- [ ] **Step 2: Run tests and confirm RED**

Run: `swift test --filter CodexSessionParserTests`
Expected: compilation fails because `CodexSessionParser` and domain types do not exist.

- [ ] **Step 3: Implement minimal quota models and streaming line parser**

Decode only the envelope, payload type, timestamp, and rate-limit metadata using private `Decodable` structs. Convert each verified `used_percent` to remaining percentage and choose the smallest remaining window. Ignore malformed or unrelated lines.

```swift
public enum QuotaTone: Equatable, Sendable {
    case healthy, warning, critical, unknown
    public static func forRemaining(_ value: Double?) -> Self {
        guard let value else { return .unknown }
        if value < 20 { return .critical }
        if value <= 50 { return .warning }
        return .healthy
    }
}
```

- [ ] **Step 4: Run tests and confirm GREEN**

Run: `swift test --filter CodexSessionParserTests`
Expected: all quota parser and threshold tests pass.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/CodexStatusCore Tests/CodexStatusCoreTests
git commit -m "feat: parse local Codex quota metadata"
```

### Task 2: Activity parsing and local repository

**Files:**
- Modify: `Sources/CodexStatusCore/CodexSessionParser.swift`
- Create: `Sources/CodexStatusCore/CodexStatusRepository.swift`
- Modify: `Tests/CodexStatusCoreTests/CodexSessionParserTests.swift`
- Create: `Tests/CodexStatusCoreTests/CodexStatusRepositoryTests.swift`

**Interfaces:**
- Consumes: `CodexSessionParser.parse(lines:now:) -> CodexSnapshot`.
- Produces: `CodexStatusRepository.loadSnapshot(now:) async -> CodexSnapshot` and injectable `sessionsRoot`.

- [ ] **Step 1: Write failing activity and repository tests**

Test event sequences `task_started`, `task_complete`, and failure event names; test selection of the newest JSONL files in a temporary directory and confirm malformed files produce an unavailable snapshot without throwing.

```swift
func testTaskStartedWithoutTerminalEventIsWorking() {
    let lines = [event("task_started", at: "2026-07-12T10:00:00Z")]
    XCTAssertEqual(parser.parse(lines: lines, now: now).activity.state, .working)
}
```

- [ ] **Step 2: Run tests and confirm RED**

Run: `swift test --filter 'CodexSessionParserTests|CodexStatusRepositoryTests'`
Expected: activity assertions fail and repository type is missing.

- [ ] **Step 3: Implement event-state reduction and file discovery**

Map the newest relevant event across inspected sessions: `task_started` to working, `task_complete` to completed, and `task_failed`/`turn_aborted`/`error` to failed. Use file modification time for bounded newest-first discovery, parse JSONL line-by-line, and retain source/update metadata only.

```swift
public enum ActivityState: String, Equatable, Sendable {
    case idle, working, completed, failed
}
```

- [ ] **Step 4: Run tests and confirm GREEN**

Run: `swift test`
Expected: all parser and repository tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexStatusCore Tests/CodexStatusCoreTests
git commit -m "feat: detect Codex task activity"
```

### Task 3: Menu Bar UI and packaged app

**Files:**
- Create: `Sources/CodexMenuBar/CodexMenuBarApp.swift`
- Create: `Sources/CodexMenuBar/StatusStore.swift`
- Create: `Sources/CodexMenuBar/MenuBarLabel.swift`
- Create: `Sources/CodexMenuBar/StatusPopover.swift`
- Create: `scripts/build-app.sh`
- Create: `README.md`
- Create: `Tests/CodexStatusCoreTests/DisplayFormattingTests.swift`

**Interfaces:**
- Consumes: `CodexStatusRepository.loadSnapshot(now:)` and core snapshot models.
- Produces: executable product `CodexMenuBar` and `dist/Codex Status.app` via build script.

- [ ] **Step 1: Write failing display-format tests**

Test capsule text for known and unknown quota and Thai activity labels for all four states.

```swift
func testUnknownQuotaUsesDash() {
    XCTAssertEqual(StatusPresentation.capsuleText(remainingPercent: nil), "Codex —")
}
```

- [ ] **Step 2: Run test and confirm RED**

Run: `swift test --filter DisplayFormattingTests`
Expected: compilation fails because `StatusPresentation` is missing.

- [ ] **Step 3: Implement presentation helpers and SwiftUI app**

Add `StatusPresentation`, an `@MainActor StatusStore` that refreshes immediately and every 30 seconds, a capsule label with quota tone and activity dot, and a popover containing both quota windows, reset time, latest activity, stale/error messaging, refresh, and quit controls. Use system adaptive colors and accessibility labels.

```swift
MenuBarExtra {
    StatusPopover(store: store)
} label: {
    MenuBarLabel(snapshot: store.snapshot)
}
.menuBarExtraStyle(.window)
```

- [ ] **Step 4: Add reproducible app-bundle build script and README**

The script runs `swift build -c release`, creates `dist/Codex Status.app/Contents/MacOS`, copies the executable, and writes an Info.plist with `LSUIElement=true`. README documents build, launch, data source, color thresholds, privacy, and current schema limitations.

- [ ] **Step 5: Run full verification**

Run: `swift test && swift build && ./scripts/build-app.sh && test -x 'dist/Codex Status.app/Contents/MacOS/CodexMenuBar'`
Expected: tests pass, debug/release builds succeed, and the app executable exists.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodexMenuBar Sources/CodexStatusCore Tests scripts README.md Package.swift
git commit -m "feat: add Codex quota menu bar app"
```

