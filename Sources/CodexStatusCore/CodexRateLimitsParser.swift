import Foundation

public struct CodexRateLimitsParser: Sendable {
    public init() {}

    public func parse(lines: [String], now: Date) -> QuotaSnapshot? {
        let decoder = JSONDecoder()

        for line in lines.reversed() {
            guard
                let data = line.data(using: .utf8),
                let response = try? decoder.decode(RateLimitsResponse.self, from: data),
                let result = response.result
            else { continue }

            let limits = result.rateLimitsByLimitID?["codex"] ?? result.rateLimits
            let windows = [limits.primary, limits.secondary].compactMap(Self.makeWindow)
            guard !windows.isEmpty else { continue }

            return QuotaSnapshot(
                limitName: limits.limitName ?? "Codex",
                windows: windows,
                observedAt: now
            )
        }

        return nil
    }

    private static func makeWindow(_ value: LiveRateLimitWindow?) -> QuotaWindow? {
        guard let value else { return nil }
        let remaining = min(100, max(0, 100 - Double(value.usedPercent)))
        return QuotaWindow(
            name: windowName(minutes: value.windowDurationMinutes),
            remainingPercent: remaining,
            windowMinutes: value.windowDurationMinutes,
            resetsAt: value.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    private static func windowName(minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "Quota" }
        if minutes.isMultiple(of: 1_440) {
            let days = minutes / 1_440
            return "\(days) day\(days == 1 ? "" : "s")"
        }
        if minutes.isMultiple(of: 60) {
            let hours = minutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
        return "\(minutes) minutes"
    }
}

private struct RateLimitsResponse: Decodable {
    let result: LiveRateLimitsResult?
}

private struct LiveRateLimitsResult: Decodable {
    let rateLimits: LiveRateLimitSnapshot
    let rateLimitsByLimitID: [String: LiveRateLimitSnapshot]?

    enum CodingKeys: String, CodingKey {
        case rateLimits
        case rateLimitsByLimitID = "rateLimitsByLimitId"
    }
}

private struct LiveRateLimitSnapshot: Decodable {
    let limitName: String?
    let primary: LiveRateLimitWindow?
    let secondary: LiveRateLimitWindow?
}

private struct LiveRateLimitWindow: Decodable {
    let usedPercent: Int
    let windowDurationMinutes: Int?
    let resetsAt: Int64?

    enum CodingKeys: String, CodingKey {
        case usedPercent
        case windowDurationMinutes = "windowDurationMins"
        case resetsAt
    }
}
