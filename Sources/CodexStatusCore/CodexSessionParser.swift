import Foundation

public struct CodexSessionParser: Sendable {
    public init() {}

    public func parse(lines: [String], now: Date) -> CodexSnapshot {
        let decoder = JSONDecoder()
        var newestQuota: (date: Date, value: QuotaSnapshot)?

        for line in lines {
            guard
                let data = line.data(using: .utf8),
                let envelope = try? decoder.decode(EventEnvelope.self, from: data),
                envelope.type == "event_msg",
                envelope.payload.type == "token_count",
                let limits = envelope.payload.rateLimits,
                let observedAt = Self.parseDate(envelope.timestamp)
            else { continue }

            let windows = [
                Self.makeWindow(name: "5 ชั่วโมง", value: limits.primary),
                Self.makeWindow(name: "7 วัน", value: limits.secondary)
            ].compactMap { $0 }

            guard !windows.isEmpty else { continue }
            let quota = QuotaSnapshot(limitName: limits.limitName, windows: windows, observedAt: observedAt)
            if newestQuota == nil || observedAt >= newestQuota!.date {
                newestQuota = (observedAt, quota)
            }
        }

        guard let quota = newestQuota?.value else {
            return .unavailable(now: now, message: "ไม่พบข้อมูลโควตา Codex ที่ตรวจสอบได้")
        }

        return CodexSnapshot(quota: quota, loadedAt: now)
    }

    private static func makeWindow(name: String, value: LimitWindow?) -> QuotaWindow? {
        guard let used = value?.usedPercent, used.isFinite else { return nil }
        let remaining = min(100, max(0, 100 - used))
        let reset = value?.resetsAt.map { Date(timeIntervalSince1970: $0) }
        return QuotaWindow(
            name: name,
            remainingPercent: remaining,
            windowMinutes: value?.windowMinutes,
            resetsAt: reset
        )
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}

private struct EventEnvelope: Decodable {
    let timestamp: String?
    let type: String
    let payload: EventPayload
}

private struct EventPayload: Decodable {
    let type: String?
    let rateLimits: RateLimits?

    enum CodingKeys: String, CodingKey {
        case type
        case rateLimits = "rate_limits"
    }
}

private struct RateLimits: Decodable {
    let limitName: String?
    let primary: LimitWindow?
    let secondary: LimitWindow?

    enum CodingKeys: String, CodingKey {
        case limitName = "limit_name"
        case primary
        case secondary
    }
}

private struct LimitWindow: Decodable {
    let usedPercent: Double?
    let windowMinutes: Int?
    let resetsAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetsAt = "resets_at"
    }
}
