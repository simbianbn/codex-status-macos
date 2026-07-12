import Combine
import CodexStatusCore
import Foundation

@MainActor
final class StatusStore: ObservableObject {
    @Published private(set) var snapshot = CodexSnapshot.unavailable(
        now: Date(),
        message: "กำลังอ่านข้อมูล Codex…"
    )
    @Published private(set) var isRefreshing = false

    private let repository: CodexStatusRepository
    private var refreshTask: Task<Void, Never>?
    private var started = false

    init(repository: CodexStatusRepository = CodexStatusRepository()) {
        self.repository = repository
    }

    func start() {
        guard !started else { return }
        started = true
        refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
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
