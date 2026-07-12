import CodexStatusCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let refreshData: () -> Void

    var body: some View {
        TabView {
            accountView
                .tabItem { Label("บัญชี", systemImage: "person.crop.circle") }
            displayView
                .tabItem { Label("การแสดงผล", systemImage: "menubar.rectangle") }
            generalView
                .tabItem { Label("ทั่วไป", systemImage: "gearshape") }
        }
        .padding(20)
        .frame(width: 520, height: 390)
    }

    private var accountView: some View {
        Form {
            Section("บัญชี Codex") {
                LabeledContent("สถานะ") {
                    Label(accountLabel, systemImage: accountIcon)
                        .foregroundStyle(accountColor)
                }
                if let mode = model.account.authMode {
                    LabeledContent("วิธีเข้าสู่ระบบ", value: mode == "chatgpt" ? "บัญชี ChatGPT" : mode)
                }
                if let refreshed = model.account.lastRefresh {
                    LabeledContent("ตรวจสอบล่าสุด", value: refreshed.formatted(date: .abbreviated, time: .shortened))
                }
                HStack {
                    Button("เข้าสู่ระบบด้วย Codex") { model.startLogin() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.isCodexAvailable)
                    Button("เปิด Codex") { model.openCodex() }
                    Button("ตรวจสอบอีกครั้ง") { model.refreshAccount() }
                }
                if let message = model.loginError ?? model.account.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("ความเป็นส่วนตัว") {
                Label("แอปอ่านเฉพาะสถานะบัญชี และไม่อ่านหรือเก็บ token, API key หรือรหัสผ่าน", systemImage: "lock.shield")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }

    private var displayView: some View {
        Form {
            Section("Menu Bar") {
                Picker("รูปแบบ", selection: $model.preferences.displayMode) {
                    Text("ไอคอน + เปอร์เซ็นต์").tag(MenuDisplayMode.iconAndPercentage)
                    Text("เปอร์เซ็นต์อย่างเดียว").tag(MenuDisplayMode.percentageOnly)
                    Text("ไอคอนอย่างเดียว").tag(MenuDisplayMode.iconOnly)
                }
                Toggle("ใช้สีตามโควตา", isOn: $model.preferences.useQuotaColors)
                Toggle("แสดงสถานะการทำงาน", isOn: $model.preferences.showActivity)
            }
            Section("ระดับแจ้งเตือน") {
                HStack {
                    Text("เปลี่ยนเป็นสีแดงเมื่อเหลือต่ำกว่า")
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
            Section("การทำงาน") {
                Toggle("เปิด Codex Status เมื่อเข้าสู่ระบบ macOS", isOn: Binding(
                    get: { model.preferences.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if let error = model.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Picker("รีเฟรชทุก", selection: $model.preferences.refreshInterval) {
                    Text("15 วินาที").tag(TimeInterval(15))
                    Text("30 วินาที").tag(TimeInterval(30))
                    Text("60 วินาที").tag(TimeInterval(60))
                }
            }
            Section("ข้อมูล") {
                LabeledContent("Codex sessions", value: "~/.codex/sessions")
                LabeledContent("เวอร์ชัน", value: appVersion)
                Button("ตรวจสอบข้อมูลตอนนี้") {
                    refreshData()
                    model.refreshAccount()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var accountLabel: String {
        switch model.account.state {
        case .checking: "กำลังตรวจสอบ"
        case .signedIn: "เข้าสู่ระบบแล้ว"
        case .signedOut: "ยังไม่ได้เข้าสู่ระบบ"
        case .unavailable: "ตรวจสอบไม่ได้"
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
