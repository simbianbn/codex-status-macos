import CodexStatusCore
import SwiftUI

struct MenuBarLabel: View {
    let snapshot: CodexSnapshot
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(activityColor)
                .frame(width: 7, height: 7)
                .scaleEffect(snapshot.activity.state == .working && pulse ? 0.65 : 1)
                .opacity(snapshot.activity.state == .working && pulse ? 0.55 : 1)

            Text(StatusPresentation.capsuleText(remainingPercent: snapshot.quota?.remainingPercent))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(capsuleColor, in: Capsule())
        .accessibilityLabel(accessibilityText)
        .onAppear { updatePulse() }
        .onChange(of: snapshot.activity.state) { _ in updatePulse() }
    }

    private func updatePulse() {
        pulse = false
        guard snapshot.activity.state == .working else { return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private var capsuleColor: Color {
        switch snapshot.quota?.tone ?? .unknown {
        case .healthy: Color(red: 0.12, green: 0.68, blue: 0.36)
        case .warning: Color(red: 0.95, green: 0.67, blue: 0.12)
        case .critical: Color(red: 0.87, green: 0.22, blue: 0.22)
        case .unknown: Color.secondary.opacity(0.45)
        }
    }

    private var foregroundColor: Color {
        snapshot.quota?.tone == .warning ? .black.opacity(0.82) : .white
    }

    private var activityColor: Color {
        switch snapshot.activity.state {
        case .idle: .gray
        case .working: .cyan
        case .completed: .green
        case .failed: .red
        }
    }

    private var accessibilityText: String {
        "\(StatusPresentation.capsuleText(remainingPercent: snapshot.quota?.remainingPercent)), \(StatusPresentation.activityLabel(snapshot.activity.state))"
    }
}
