import Foundation

public enum AccountState: String, Equatable, Sendable {
    case checking
    case signedIn
    case signedOut
    case unavailable
}

public struct AccountSnapshot: Equatable, Sendable {
    public let state: AccountState
    public let authMode: String?
    public let lastRefresh: Date?
    public let message: String?

    public init(state: AccountState, authMode: String? = nil, lastRefresh: Date? = nil, message: String? = nil) {
        self.state = state
        self.authMode = authMode
        self.lastRefresh = lastRefresh
        self.message = message
    }
}

public struct CodexAccountProvider: Sendable {
    public static let loginArguments = ["login"]
    public let authFile: URL

    public init(
        authFile: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
    ) {
        self.authFile = authFile
    }

    public func loadStatus() -> AccountSnapshot {
        guard FileManager.default.fileExists(atPath: authFile.path) else {
            return AccountSnapshot(state: .signedOut, message: "ยังไม่พบข้อมูลการเข้าสู่ระบบ Codex")
        }
        guard let contents = try? String(contentsOf: authFile, encoding: .utf8) else {
            return AccountSnapshot(state: .unavailable, message: "ไม่สามารถอ่านสถานะบัญชี Codex ได้")
        }
        return parse(contents)
    }

    public func parse(_ contents: String) -> AccountSnapshot {
        guard let data = contents.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(SafeAuthMetadata.self, from: data) else {
            return AccountSnapshot(state: .unavailable, message: "รูปแบบข้อมูลบัญชี Codex ไม่รองรับ")
        }
        guard let authMode = metadata.authMode, !authMode.isEmpty else {
            return AccountSnapshot(state: .signedOut, message: "ยังไม่ได้เข้าสู่ระบบ Codex")
        }
        return AccountSnapshot(
            state: .signedIn,
            authMode: authMode,
            lastRefresh: metadata.lastRefresh.flatMap(Self.parseDate)
        )
    }

    public func resolvedExecutable() -> URL? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex"
        ]
        return candidates.lazy.map(URL.init(fileURLWithPath:)).first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private struct SafeAuthMetadata: Decodable {
    let authMode: String?
    let lastRefresh: String?

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case lastRefresh = "last_refresh"
    }
}
