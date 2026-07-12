import AppKit
import CodexStatusCore
import SwiftUI

struct StatusPopover: View {
    @ObservedObject var store: StatusStore
    @ObservedObject var settings: SettingsModel
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            quotaSection
            Divider()
            activitySection
            accountSection
            if let message = store.snapshot.errorMessage {
                errorBanner(message)
            } else if store.snapshot.isStale {
                staleBanner
            }
            footer
        }
        .padding(18)
        .frame(width: 330)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Status")
                    .font(.title3.bold())
                Text(store.snapshot.quota?.limitName ?? "Local quota")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(StatusPresentation.capsuleText(remainingPercent: store.snapshot.quota?.remainingPercent))
                .font(.headline.monospacedDigit())
        }
    }

    @ViewBuilder
    private var quotaSection: some View {
        if let quota = store.snapshot.quota, let remaining = quota.remainingPercent {
            VStack(alignment: .leading, spacing: 10) {
                Label("Quota remaining", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.headline)
                ProgressView(value: remaining, total: 100)
                    .tint(toneColor(quota.tone))
                ForEach(Array(quota.windows.enumerated()), id: \.offset) { _, window in
                    HStack {
                        Text(window.name)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Int(window.remainingPercent.rounded()))% remaining")
                                .monospacedDigit()
                            if let reset = window.resetsAt {
                                Text("Resets \(reset.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .font(.subheadline)
                }
            }
        } else {
            Label("No verified quota data yet", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private var activitySection: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(activityColor(store.snapshot.activity.state))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text("Task status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(StatusPresentation.activityLabel(store.snapshot.activity.state))
                    .font(.headline)
                if let time = store.snapshot.activity.observedAt {
                    Text(time.formatted(date: .omitted, time: .standard))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
    }

    private var staleBanner: some View {
        Label("Data may be stale", systemImage: "clock.badge.exclamationmark")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    private var footer: some View {
        HStack {
            Text("Updated \(store.snapshot.loadedAt.formatted(date: .omitted, time: .standard))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                store.refresh()
            } label: {
                if store.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .disabled(store.isRefreshing)
            Button("Quit") { NSApplication.shared.terminate(nil) }
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Open Settings")
        }
    }

    private var accountSection: some View {
        HStack {
            Label(
                settings.account.state == .signedIn ? "Signed in to Codex" : "Not signed in to Codex",
                systemImage: settings.account.state == .signedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark"
            )
            .font(.caption)
            Spacer()
            Button("Settings") { openSettings() }
                .buttonStyle(.link)
        }
    }

    private func toneColor(_ tone: QuotaTone) -> Color {
        switch tone {
        case .healthy: .green
        case .warning: .yellow
        case .critical: .red
        case .unknown: .gray
        }
    }

    private func activityColor(_ state: ActivityState) -> Color {
        switch state {
        case .idle: .gray
        case .working: .blue
        case .completed: .green
        case .failed: .red
        }
    }
}
