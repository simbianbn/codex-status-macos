import Darwin
import Dispatch
import Foundation

public final class SessionFileMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.codex.statusbar.session-monitor", qos: .utility)
    private let lock = NSLock()
    private var source: DispatchSourceFileSystemObject?

    public init() {}

    @discardableResult
    public func watch(fileURL: URL, onChange: @escaping @Sendable () -> Void) -> Bool {
        stop()

        let descriptor = open(fileURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return false }

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        newSource.setEventHandler(handler: onChange)
        newSource.setCancelHandler {
            close(descriptor)
        }

        lock.lock()
        source = newSource
        lock.unlock()
        newSource.resume()
        return true
    }

    public func stop() {
        lock.lock()
        let oldSource = source
        source = nil
        lock.unlock()
        oldSource?.cancel()
    }

    deinit {
        stop()
    }
}
