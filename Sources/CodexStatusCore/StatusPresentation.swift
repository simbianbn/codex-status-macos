import Foundation

public enum StatusPresentation {
    public static func capsuleText(remainingPercent: Double?) -> String {
        guard let remainingPercent else { return "Codex —" }
        return "Codex \(Int(remainingPercent.rounded()))%"
    }

    public static func activityLabel(_ state: ActivityState) -> String {
        switch state {
        case .idle: "ว่าง"
        case .working: "กำลังทำงาน"
        case .completed: "เสร็จ"
        case .failed: "เกิดข้อผิดพลาด"
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
}
