import Foundation

public enum QuotaTone: Equatable, Sendable {
    case healthy
    case warning
    case critical
    case unknown

    public static func forRemaining(_ value: Double?) -> Self {
        guard let value else { return .unknown }
        if value < 20 { return .critical }
        if value <= 50 { return .warning }
        return .healthy
    }
}

public struct QuotaWindow: Equatable, Sendable {
    public let name: String
    public let remainingPercent: Double
    public let windowMinutes: Int?
    public let resetsAt: Date?

    public init(name: String, remainingPercent: Double, windowMinutes: Int?, resetsAt: Date?) {
        self.name = name
        self.remainingPercent = remainingPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }
}

public struct QuotaSnapshot: Equatable, Sendable {
    public let limitName: String?
    public let windows: [QuotaWindow]
    public let observedAt: Date

    public var remainingPercent: Double? {
        windows.map(\.remainingPercent).min()
    }

    public var tone: QuotaTone {
        QuotaTone.forRemaining(remainingPercent)
    }
}

public enum ActivityState: String, Equatable, Sendable {
    case idle
    case working
    case completed
    case failed
}

public struct TaskActivity: Equatable, Sendable {
    public let state: ActivityState
    public let observedAt: Date?

    public init(state: ActivityState = .idle, observedAt: Date? = nil) {
        self.state = state
        self.observedAt = observedAt
    }
}

public struct CodexSnapshot: Equatable, Sendable {
    public let quota: QuotaSnapshot?
    public let activity: TaskActivity
    public let loadedAt: Date
    public let sourcePath: String?
    public let errorMessage: String?
    public let isStale: Bool

    public init(
        quota: QuotaSnapshot?,
        activity: TaskActivity = TaskActivity(),
        loadedAt: Date,
        sourcePath: String? = nil,
        errorMessage: String? = nil,
        isStale: Bool = false
    ) {
        self.quota = quota
        self.activity = activity
        self.loadedAt = loadedAt
        self.sourcePath = sourcePath
        self.errorMessage = errorMessage
        self.isStale = isStale
    }

    public static func unavailable(now: Date, message: String) -> CodexSnapshot {
        CodexSnapshot(quota: nil, loadedAt: now, errorMessage: message)
    }
}
