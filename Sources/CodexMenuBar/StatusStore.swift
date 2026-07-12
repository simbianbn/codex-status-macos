import Combine
import CodexStatusCore
import Foundation

@MainActor
final class StatusStore: ObservableObject {
    @Published private(set) var snapshot = CodexSnapshot.unavailable(
        now: Date(),
        message: "Reading Codex data…"
    )
    @Published private(set) var isRefreshing = false

    private let repository: CodexStatusRepository
    private var refreshTask: Task<Void, Never>?
    private var started = false
    private(set) var refreshInterval: TimeInterval = 30

    init(repository: CodexStatusRepository = CodexStatusRepository()) {
        self.repository = repository
    }

    func start() {
        guard !started else { return }
        started = true
        refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.refreshInterval ?? 30))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = [15, 30, 60].contains(interval) ? interval : 30
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let repository = repository
        Task { [weak self] in
            let newSnapshot = await Task.detached {
                await repository.loadSnapshot(now: Date())
            }.value
            guard let self else { return }
            snapshot = newSnapshot
            isRefreshing = false
        }
    }
}
