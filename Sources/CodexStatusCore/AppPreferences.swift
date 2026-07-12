import Foundation

public enum MenuDisplayMode: String, CaseIterable, Equatable, Sendable {
    case iconAndPercentage
    case percentageOnly
    case iconOnly
}

public struct PreferenceValues: Equatable, Sendable {
    public var displayMode: MenuDisplayMode
    public var useQuotaColors: Bool
    public var criticalThreshold: Double
    public var showActivity: Bool
    public var refreshInterval: TimeInterval
    public var launchAtLogin: Bool

    public init(
        displayMode: MenuDisplayMode = .iconAndPercentage,
        useQuotaColors: Bool = true,
        criticalThreshold: Double = 20,
        showActivity: Bool = true,
        refreshInterval: TimeInterval = 30,
        launchAtLogin: Bool = false
    ) {
        self.displayMode = displayMode
        self.useQuotaColors = useQuotaColors
        self.criticalThreshold = min(40, max(5, criticalThreshold))
        self.showActivity = showActivity
        self.refreshInterval = [15, 30, 60].contains(refreshInterval) ? refreshInterval : 30
        self.launchAtLogin = launchAtLogin
    }
}

public struct PreferenceStore: Sendable {
    private let suiteName: String

    public init(suiteName: String = "local.codex.statusbar") {
        self.suiteName = suiteName
    }

    public func load() -> PreferenceValues {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return PreferenceValues() }
        return PreferenceValues(
            displayMode: MenuDisplayMode(rawValue: defaults.string(forKey: Keys.displayMode) ?? "") ?? .iconAndPercentage,
            useQuotaColors: defaults.object(forKey: Keys.useQuotaColors) as? Bool ?? true,
            criticalThreshold: defaults.object(forKey: Keys.criticalThreshold) as? Double ?? 20,
            showActivity: defaults.object(forKey: Keys.showActivity) as? Bool ?? true,
            refreshInterval: defaults.object(forKey: Keys.refreshInterval) as? Double ?? 30,
            launchAtLogin: defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        )
    }

    public func save(_ values: PreferenceValues) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(values.displayMode.rawValue, forKey: Keys.displayMode)
        defaults.set(values.useQuotaColors, forKey: Keys.useQuotaColors)
        defaults.set(values.criticalThreshold, forKey: Keys.criticalThreshold)
        defaults.set(values.showActivity, forKey: Keys.showActivity)
        defaults.set(values.refreshInterval, forKey: Keys.refreshInterval)
        defaults.set(values.launchAtLogin, forKey: Keys.launchAtLogin)
    }

    private enum Keys {
        static let displayMode = "displayMode"
        static let useQuotaColors = "useQuotaColors"
        static let criticalThreshold = "criticalThreshold"
        static let showActivity = "showActivity"
        static let refreshInterval = "refreshInterval"
        static let launchAtLogin = "launchAtLogin"
    }
}
