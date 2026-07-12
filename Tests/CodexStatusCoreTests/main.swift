import Foundation
import CodexStatusCore

@main
enum CodexStatusTests {
    static func main() {
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

        tests.finish()
    }

    private static func quotaLine(timestamp: String, primaryUsed: Double) -> String {
        #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_name":"Codex","primary":{"used_percent":\#(primaryUsed),"window_minutes":300,"resets_at":1783854000}}}}"#
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
