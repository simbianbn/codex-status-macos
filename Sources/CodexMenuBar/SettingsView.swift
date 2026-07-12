import CodexStatusCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let refreshData: () -> Void

    var body: some View {
        TabView {
            accountView
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
            displayView
                .tabItem { Label("Display", systemImage: "menubar.rectangle") }
            generalView
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding(20)
        .frame(width: 520, height: 390)
    }

    private var accountView: some View {
        Form {
            Section("Codex Account") {
                LabeledContent("Status") {
                    Label(accountLabel, systemImage: accountIcon)
                        .foregroundStyle(accountColor)
                }
                if let mode = model.account.authMode {
                    LabeledContent("Sign-in method", value: mode == "chatgpt" ? "ChatGPT account" : mode)
                }
                if let refreshed = model.account.lastRefresh {
                    LabeledContent("Last checked", value: refreshed.formatted(date: .abbreviated, time: .shortened))
                }
                HStack {
                    Button("Sign in with Codex") { model.startLogin() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.isCodexAvailable)
                    Button("Open Codex") { model.openCodex() }
                    Button("Check Again") { model.refreshAccount() }
                }
                if let message = model.loginError ?? model.account.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Privacy") {
                Label("The app only reads account status. It never reads or stores tokens, API keys, or passwords.", systemImage: "lock.shield")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }

    private var displayView: some View {
        Form {
            Section("Menu Bar") {
                Picker("Format", selection: $model.preferences.displayMode) {
                    Text("Icon + percentages").tag(MenuDisplayMode.iconAndPercentage)
                    Text("Percentages only").tag(MenuDisplayMode.percentageOnly)
                    Text("Icon only").tag(MenuDisplayMode.iconOnly)
                }
                Toggle("Color by quota level", isOn: $model.preferences.useQuotaColors)
                Toggle("Show task status", isOn: $model.preferences.showActivity)
            }
            Section("Warning Level") {
                HStack {
                    Text("Turn red below")
                    Slider(value: $model.preferences.criticalThreshold, in: 5...40, step: 5)
                    Text("\(Int(model.preferences.criticalThreshold))%")
                        .monospacedDigit().frame(width: 38)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var generalView: some View {
        Form {
            Section("Behavior") {
                Toggle("Open Codex Status at macOS login", isOn: Binding(
                    get: { model.preferences.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if let error = model.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Picker("Refresh every", selection: $model.preferences.refreshInterval) {
                    Text("15 seconds").tag(TimeInterval(15))
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("60 seconds").tag(TimeInterval(60))
                }
            }
            Section("Data") {
                LabeledContent("Codex sessions", value: "~/.codex/sessions")
                LabeledContent("Version", value: appVersion)
                Button("Check Data Now") {
                    refreshData()
                    model.refreshAccount()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var accountLabel: String {
        switch model.account.state {
        case .checking: "Checking"
        case .signedIn: "Signed In"
        case .signedOut: "Signed Out"
        case .unavailable: "Unavailable"
        }
    }

    private var accountIcon: String {
        model.account.state == .signedIn ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark"
    }

    private var accountColor: Color {
        model.account.state == .signedIn ? .green : .secondary
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }
}
