import Foundation
import CodexStatusCore

@main
enum CodexStatusTests {
    static func main() async {
        var tests = TestSuite()
        let now = Date(timeIntervalSince1970: 1_783_850_000)
        let parser = CodexSessionParser()

        let constrained = #"{"timestamp":"2026-07-12T10:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_name":"Codex","primary":{"used_percent":25,"window_minutes":300,"resets_at":1783854000},"secondary":{"used_percent":60,"window_minutes":10080,"resets_at":1784458800}}}}"#
        let constrainedResult = parser.parse(lines: [constrained], now: now)
        tests.expect(constrainedResult.quota?.remainingPercent == 40, "uses most constrained quota window")
        tests.expect(constrainedResult.quota?.tone == .warning, "maps 40 percent to warning")
        tests.expect(constrainedResult.quota?.limitName == "Codex", "preserves limit name")
        tests.expect(constrainedResult.quota?.windows.count == 2, "preserves both windows")

        let older = quotaLine(timestamp: "2026-07-12T10:00:00Z", primaryUsed: 70)
        let newer = quotaLine(timestamp: "2026-07-12T10:01:00Z", primaryUsed: 20)
        tests.expect(parser.parse(lines: [older, newer], now: now).quota?.remainingPercent == 80, "latest quota event wins")

        let unavailable = parser.parse(lines: ["not-json", #"{"type":"event_msg","payload":{"type":"agent_message"}}"#], now: now)
        tests.expect(unavailable.quota == nil, "malformed input has no quota")
        tests.expect(unavailable.errorMessage != nil, "malformed input explains unavailable quota")

        let clamped = parser.parse(lines: [quotaLine(timestamp: "2026-07-12T10:00:00Z", primaryUsed: 140)], now: now)
        tests.expect(clamped.quota?.remainingPercent == 0, "remaining percentage is clamped")
        tests.expect(QuotaTone.forRemaining(19) == .critical, "19 is critical")
        tests.expect(QuotaTone.forRemaining(20) == .warning, "20 is warning")
        tests.expect(QuotaTone.forRemaining(50) == .warning, "50 is warning")
        tests.expect(QuotaTone.forRemaining(51) == .healthy, "51 is healthy")
        tests.expect(QuotaTone.forRemaining(nil) == .unknown, "nil is unknown")
        tests.expect(StatusPresentation.capsuleText(remainingPercent: nil) == "Codex —", "unknown quota uses dash")
        tests.expect(StatusPresentation.capsuleText(remainingPercent: 72.4) == "Codex 72%", "capsule rounds quota")
        tests.expect(StatusPresentation.activityLabel(.idle) == "ว่าง", "idle Thai label")
        tests.expect(StatusPresentation.activityLabel(.working) == "กำลังทำงาน", "working Thai label")
        tests.expect(StatusPresentation.activityLabel(.completed) == "เสร็จ", "completed Thai label")
        tests.expect(StatusPresentation.activityLabel(.failed) == "เกิดข้อผิดพลาด", "failed Thai label")

        let accountProvider = CodexAccountProvider(authFile: URL(fileURLWithPath: "/tmp/unused-auth.json"))
        let signedInAccount = accountProvider.parse(#"{"auth_mode":"chatgpt","last_refresh":"2026-07-12T10:00:00Z","tokens":{"access_token":"SECRET_VALUE"}}"#)
        tests.expect(signedInAccount.state == .signedIn, "detects ChatGPT account")
        tests.expect(signedInAccount.authMode == "chatgpt", "keeps safe auth mode")
        tests.expect(!String(describing: signedInAccount).contains("SECRET_VALUE"), "never exposes credential values")
        tests.expect(accountProvider.parse("{}").state == .signedOut, "empty auth is signed out")
        tests.expect(accountProvider.parse("not-json").state == .unavailable, "malformed auth is unavailable")
        tests.expect(CodexAccountProvider.loginArguments == ["login"], "uses official Codex login flow")

        tests.expect(PreferenceValues().displayMode == .iconAndPercentage, "default display mode")
        tests.expect(PreferenceValues(criticalThreshold: 99).criticalThreshold == 40, "clamps high critical threshold")
        tests.expect(PreferenceValues(criticalThreshold: 1).criticalThreshold == 5, "clamps low critical threshold")
        tests.expect(PreferenceValues(refreshInterval: 17).refreshInterval == 30, "invalid refresh interval uses default")
        tests.expect(StatusPresentation.compactText(mode: .iconAndPercentage, remainingPercent: 72) == "C 72%", "icon and percentage mode")
        tests.expect(StatusPresentation.compactText(mode: .percentageOnly, remainingPercent: 72) == "72%", "percentage only mode")
        tests.expect(StatusPresentation.compactText(mode: .iconOnly, remainingPercent: 72) == "C", "icon only mode")

        let started = parser.parse(lines: [event("task_started", at: "2026-07-12T10:00:00Z")], now: now)
        tests.expect(started.activity.state == .working, "task_started is working")

        let completed = parser.parse(lines: [
            event("task_started", at: "2026-07-12T10:00:00Z"),
            event("task_complete", at: "2026-07-12T10:01:00Z")
        ], now: now)
        tests.expect(completed.activity.state == .completed, "task_complete is completed")

        let failed = parser.parse(lines: [
            event("task_started", at: "2026-07-12T10:00:00Z"),
            event("turn_aborted", at: "2026-07-12T10:01:00Z")
        ], now: now)
        tests.expect(failed.activity.state == .failed, "turn_aborted is failed")

        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let day = root.appendingPathComponent("2026/07/12")
            try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
            let olderFile = day.appendingPathComponent("older.jsonl")
            let newerFile = day.appendingPathComponent("newer.jsonl")
            try quotaLine(timestamp: "2026-07-12T09:00:00Z", primaryUsed: 80).write(to: olderFile, atomically: true, encoding: .utf8)
            try quotaLine(timestamp: "2026-07-12T10:00:00Z", primaryUsed: 30).write(to: newerFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: olderFile.path)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: newerFile.path)
            let repository = CodexStatusRepository(sessionsRoot: root)
            let snapshot = await repository.loadSnapshot(now: now)
            tests.expect(snapshot.quota?.remainingPercent == 70, "repository reads newest session metadata")
            let expectedSource = newerFile.resolvingSymlinksInPath().path
            let actualSource = snapshot.sourcePath.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
            tests.expect(actualSource == expectedSource, "repository records selected source path")
            try? FileManager.default.removeItem(at: root)
        } catch {
            tests.expect(false, "repository fixture setup: \(error)")
        }

        tests.finish()
    }

    private static func quotaLine(timestamp: String, primaryUsed: Double) -> String {
        #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_name":"Codex","primary":{"used_percent":\#(primaryUsed),"window_minutes":300,"resets_at":1783854000}}}}"#
    }

    private static func event(_ type: String, at timestamp: String) -> String {
        #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"\#(type)"}}"#
    }
}

struct TestSuite {
    private(set) var failures = 0
    private(set) var count = 0

    mutating func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        count += 1
        if condition() {
            print("PASS: \(name)")
        } else {
            failures += 1
            print("FAIL: \(name)")
        }
    }

    func finish() -> Never {
        print("\(count - failures)/\(count) checks passed")
        Foundation.exit(failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
    }
}
