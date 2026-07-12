import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let model: SettingsModel
    private let refreshData: () -> Void
    private var window: NSWindow?

    init(model: SettingsModel, refreshData: @escaping () -> Void) {
        self.model = model
        self.refreshData = refreshData
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = NSHostingController(rootView: SettingsView(model: model, refreshData: refreshData))
        let window = NSWindow(contentViewController: controller)
        window.title = "Codex Status Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 390))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
