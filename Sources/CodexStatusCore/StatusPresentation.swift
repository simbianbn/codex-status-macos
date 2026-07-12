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

    public static func menuBarQuotaText(mode: MenuDisplayMode, windows: [QuotaWindow]) -> String {
        if mode == .iconOnly { return "C" }
        let ordered = windows.sorted { ($0.windowMinutes ?? .max) < ($1.windowMinutes ?? .max) }
        let fiveHour = ordered.first { $0.windowMinutes == 300 }
        let weekly = ordered.first { $0.windowMinutes == 10_080 }
        guard let fiveHour, let weekly else {
            return compactText(mode: mode, remainingPercent: ordered.map(\.remainingPercent).min())
        }
        let values = "\(Int(fiveHour.remainingPercent.rounded()))% · \(Int(weekly.remainingPercent.rounded()))%"
        return mode == .iconAndPercentage
            ? "5H \(Int(fiveHour.remainingPercent.rounded()))% · 7D \(Int(weekly.remainingPercent.rounded()))%"
            : values
    }
}
