import Combine
import CodexStatusCore
import Foundation
import OSLog

@MainActor
final class StatusStore: ObservableObject {
    private let logger = Logger(subsystem: "local.codex.statusbar", category: "Refresh")
    @Published private(set) var snapshot = CodexSnapshot.unavailable(
        now: Date(),
        message: "Reading Codex data…"
    )
    @Published private(set) var isRefreshing = false

    private let repository: CodexStatusRepository
    private let sessionMonitor = SessionFileMonitor()
    private var refreshTask: Task<Void, Never>?
    private var fileRefreshTask: Task<Void, Never>?
    private var monitoredPath: String?
    private var started = false
    private(set) var refreshInterval: TimeInterval = 30

    init(repository: CodexStatusRepository = CodexStatusRepository()) {
        self.repository = repository
    }

    func start() {
        guard !started else { return }
        started = true
        logger.info("Starting automatic refresh loop")
        refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.refreshInterval ?? 30))
                guard !Task.isCancelled else { return }
                self?.logger.info("Automatic refresh timer fired")
                self?.refresh()
            }
        }
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = [15, 30, 60].contains(interval) ? interval : 30
    }

    func refresh() {
        guard !isRefreshing else {
            logger.debug("Refresh skipped because a load is already running")
            return
        }
        logger.info("Loading Codex snapshot")
        isRefreshing = true
        let repository = repository
        Task { [weak self] in
            let newSnapshot = await Task.detached {
                await repository.loadSnapshot(now: Date())
            }.value
            guard let self else { return }
            snapshot = newSnapshot
            isRefreshing = false
            monitorSessionFile(at: newSnapshot.sourcePath)
            logger.info("Codex snapshot loaded; quota available: \(newSnapshot.quota != nil, privacy: .public)")
        }
    }

    private func monitorSessionFile(at path: String?) {
        guard path != monitoredPath else { return }
        monitoredPath = path
        guard let path else {
            sessionMonitor.stop()
            return
        }

        let started = sessionMonitor.watch(fileURL: URL(fileURLWithPath: path)) { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleFileRefresh()
            }
        }
        logger.info("Session file monitoring active: \(started, privacy: .public)")
    }

    private func scheduleFileRefresh() {
        fileRefreshTask?.cancel()
        fileRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.logger.debug("Session file changed; refreshing snapshot")
            self?.refresh()
        }
    }
}
