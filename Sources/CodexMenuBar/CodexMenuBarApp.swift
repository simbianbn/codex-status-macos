import AppKit
import Combine
import CodexStatusCore
import SwiftUI

@main
enum CodexMenuBarMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = StatusStore()
    private let settings = SettingsModel()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var snapshotCancellable: AnyCancellable?
    private lazy var settingsWindow = SettingsWindowController(model: settings) { [weak store] in
        store?.refresh()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "CodexStatusCapsule"
        item.isVisible = true
        guard let button = item.button else { return }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 330, height: 430)
        popover.contentViewController = NSHostingController(rootView: StatusPopover(
            store: store,
            settings: settings,
            openSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.settingsWindow.show()
            }
        ))

        statusItem = item
        snapshotCancellable = Publishers.CombineLatest(store.$snapshot, settings.$preferences).sink { [weak button, weak store] snapshot, preferences in
            store?.updateRefreshInterval(preferences.refreshInterval)
            button?.image = StatusCapsuleImage.make(snapshot: snapshot, preferences: preferences)
            button?.setAccessibilityLabel(
                "\(StatusPresentation.capsuleText(remainingPercent: snapshot.quota?.remainingPercent)), \(StatusPresentation.activityLabel(snapshot.activity.state))"
            )
        }
        store.start()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            store.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@MainActor
private enum StatusCapsuleImage {
    static func make(snapshot: CodexSnapshot, preferences: PreferenceValues) -> NSImage {
        let text = StatusPresentation.compactText(
            mode: preferences.displayMode,
            remainingPercent: snapshot.quota?.remainingPercent
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: textColor(snapshot: snapshot, preferences: preferences)
        ]
        let textSize = text.size(withAttributes: attributes)
        let activitySpace: CGFloat = preferences.showActivity ? 17 : 8
        let size = NSSize(width: max(30, textSize.width + activitySpace + 8), height: 22)
        let image = NSImage(size: size, flipped: false) { rect in
            capsuleColor(snapshot: snapshot, preferences: preferences).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 2), xRadius: 9, yRadius: 9).fill()

            if preferences.showActivity {
                activityColor(snapshot.activity.state).setFill()
                NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 7, height: 7)).fill()
            }
            text.draw(
                at: NSPoint(x: activitySpace, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func capsuleColor(snapshot: CodexSnapshot, preferences: PreferenceValues) -> NSColor {
        guard preferences.useQuotaColors else { return NSColor.controlAccentColor.withAlphaComponent(0.85) }
        let tone = tone(snapshot: snapshot, preferences: preferences)
        return switch tone {
        case .healthy: NSColor(red: 0.12, green: 0.68, blue: 0.36, alpha: 1)
        case .warning: NSColor(red: 0.95, green: 0.67, blue: 0.12, alpha: 1)
        case .critical: NSColor(red: 0.87, green: 0.22, blue: 0.22, alpha: 1)
        case .unknown: NSColor.secondaryLabelColor.withAlphaComponent(0.5)
        }
    }

    private static func textColor(snapshot: CodexSnapshot, preferences: PreferenceValues) -> NSColor {
        tone(snapshot: snapshot, preferences: preferences) == .warning
            ? NSColor.black.withAlphaComponent(0.82)
            : NSColor.white
    }

    private static func tone(snapshot: CodexSnapshot, preferences: PreferenceValues) -> QuotaTone {
        guard let remaining = snapshot.quota?.remainingPercent else { return .unknown }
        if remaining < preferences.criticalThreshold { return .critical }
        if remaining <= 50 { return .warning }
        return .healthy
    }

    private static func activityColor(_ state: ActivityState) -> NSColor {
        switch state {
        case .idle: .systemGray
        case .working: .systemCyan
        case .completed: .systemGreen
        case .failed: .systemRed
        }
    }
}
