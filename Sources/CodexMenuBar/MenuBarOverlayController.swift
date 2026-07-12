import AppKit

@MainActor
final class MenuBarOverlayController {
    let button = NSButton(frame: .zero)
    private let panel: NSPanel

    init(target: AnyObject, action: Selector) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 72, height: NSStatusBar.system.thickness),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Codex Status Capsule"
        panel.setAccessibilityTitle("Codex Status Capsule")
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = false

        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.target = target
        button.action = action
        button.sendAction(on: [.leftMouseUp])
        panel.contentView = button
    }

    func update(image: NSImage, accessibilityLabel: String) {
        button.image = image
        button.setAccessibilityLabel(accessibilityLabel)
        let width = image.size.width + 6
        let screen = NSScreen.screens.first
        let height = max(NSStatusBar.system.thickness, screen?.safeAreaInsets.top ?? 0)
        panel.setFrame(frame(width: width, height: height), display: true)
        button.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
        panel.orderFrontRegardless()
    }

    private func frame(width: CGFloat, height: CGFloat) -> NSRect {
        guard let screen = NSScreen.screens.first else {
            return NSRect(x: 1000, y: 0, width: width, height: height)
        }
        let screenFrame = screen.frame
        let x: CGFloat
        if let rightArea = screen.auxiliaryTopRightArea,
           !rightArea.isEmpty,
           rightArea.width > width + 20 {
            x = rightArea.minX + 12
        } else {
            x = max(screenFrame.minX + 12, screenFrame.maxX - 520)
        }
        return NSRect(
            x: x,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }
}
