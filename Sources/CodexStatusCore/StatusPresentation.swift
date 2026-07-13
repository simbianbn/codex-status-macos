import Foundation

public enum StatusPresentation {
    public static func capsuleText(remainingPercent: Double?) -> String {
        guard let remainingPercent else { return "Codex —" }
        return "Codex \(Int(remainingPercent.rounded()))%"
    }

    public static func activityLabel(_ state: ActivityState) -> String {
        switch state {
        case .idle: "Idle"
        case .working: "Working"
        case .completed: "Completed"
        case .failed: "Error"
        }
    }

    public static func compactText(mode: MenuDisplayMode, remainingPercent: Double?) -> String {
        let percentage = remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—"
        switch mode {
        case .iconAndPercentage: return "C \(percentage)"
        case .percentageOnly: return percentage
        case .iconOnly: return "C"
        }
    }

    public static func menuBarQuotaText(mode: MenuDisplayMode, windows: [QuotaWindow], now: Date) -> String {
        if mode == .iconOnly { return "C" }
        let ordered = windows.sorted { ($0.windowMinutes ?? .max) < ($1.windowMinutes ?? .max) }
        guard !ordered.isEmpty else {
            return compactText(mode: mode, remainingPercent: nil)
        }
        if ordered.count == 1, let window = ordered.first {
            let percentage = "\(Int(window.remainingPercent.rounded()))%"
            guard mode == .iconAndPercentage else { return percentage }
            guard let resetsAt = window.resetsAt else { return "Codex: \(percentage)" }
            return "Codex: \(percentage) (\(resetCountdown(until: resetsAt, now: now)))"
        }
        return ordered.map { window in
            let percentage = "\(Int(window.remainingPercent.rounded()))%"
            guard mode == .iconAndPercentage else { return percentage }
            return "\(windowAbbreviation(minutes: window.windowMinutes)) \(percentage)"
        }.joined(separator: " · ")
    }

    private static func windowAbbreviation(minutes: Int?) -> String {
        guard let minutes else { return "C" }
        if minutes.isMultiple(of: 1_440) { return "\(minutes / 1_440)D" }
        if minutes.isMultiple(of: 60) { return "\(minutes / 60)H" }
        return "\(minutes)M"
    }

    private static func resetCountdown(until reset: Date, now: Date) -> String {
        let remaining = Int(reset.timeIntervalSince(now))
        guard remaining > 0 else { return "resetting" }

        let days = remaining / 86_400
        let hours = remaining % 86_400 / 3_600
        if days > 0 { return "\(days)d \(hours)h" }

        let minutes = remaining % 3_600 / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
