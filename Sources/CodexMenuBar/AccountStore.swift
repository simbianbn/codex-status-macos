import AppKit
import CodexStatusCore
import Foundation
import ServiceManagement

@MainActor
final class SettingsModel: ObservableObject {
    @Published var preferences: PreferenceValues {
        didSet { preferenceStore.save(preferences) }
    }
    @Published private(set) var account = AccountSnapshot(state: .checking)
    @Published private(set) var loginError: String?
    @Published private(set) var launchAtLoginError: String?

    private let accountProvider: CodexAccountProvider
    private let preferenceStore: PreferenceStore
    private var loginProcess: Process?
    private var accountPollingTask: Task<Void, Never>?

    init(
        accountProvider: CodexAccountProvider = CodexAccountProvider(),
        preferenceStore: PreferenceStore = PreferenceStore()
    ) {
        self.accountProvider = accountProvider
        self.preferenceStore = preferenceStore
        self.preferences = preferenceStore.load()
        refreshAccount()
    }

    var isCodexAvailable: Bool { accountProvider.resolvedExecutable() != nil }

    func refreshAccount() {
        account = accountProvider.loadStatus()
    }

    func startLogin() {
        guard loginProcess?.isRunning != true else { return }
        guard let executable = accountProvider.resolvedExecutable() else {
            loginError = "ไม่พบ Codex CLI ในเครื่อง กรุณาเปิด Codex และอัปเดตเป็นเวอร์ชันล่าสุด"
            return
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = CodexAccountProvider.loginArguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.refreshAccount() }
        }
        do {
            try process.run()
            loginProcess = process
            loginError = nil
            startPollingAccount()
        } catch {
            loginError = "ไม่สามารถเริ่มการเข้าสู่ระบบ Codex ได้"
        }
    }

    func openCodex() {
        let url = URL(fileURLWithPath: "/Applications/ChatGPT.app")
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            preferences.launchAtLogin = enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "ไม่สามารถเปลี่ยนการเปิดพร้อมระบบได้ในขณะนี้"
            preferences.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func startPollingAccount() {
        accountPollingTask?.cancel()
        accountPollingTask = Task { [weak self] in
            for _ in 0..<60 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(2))
                guard let self else { return }
                refreshAccount()
                if account.state == .signedIn { return }
            }
        }
    }
}
