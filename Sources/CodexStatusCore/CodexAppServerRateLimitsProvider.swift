import Foundation

public protocol CodexRateLimitsProviding: Sendable {
    func loadQuota(now: Date) async -> QuotaSnapshot?
}

public struct CodexAppServerRateLimitsProvider: CodexRateLimitsProviding, Sendable {
    private let executableURL: URL?
    private let parser: CodexRateLimitsParser

    public init(
        executableURL: URL? = Self.defaultExecutableURL(),
        parser: CodexRateLimitsParser = CodexRateLimitsParser()
    ) {
        self.executableURL = executableURL
        self.parser = parser
    }

    public func loadQuota(now: Date) async -> QuotaSnapshot? {
        guard let executableURL else { return nil }
        let parser = parser

        return await Task.detached(priority: .utility) {
            let process = Process()
            let input = Pipe()
            let output = Pipe()
            process.executableURL = executableURL
            process.arguments = ["app-server", "--stdio"]
            process.standardInput = input
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                let requests = [
                    #"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-status","version":"1.0.0"},"capabilities":{"experimentalApi":true}}}"#,
                    #"{"method":"initialized"}"#,
                    #"{"id":2,"method":"account/rateLimits/read","params":null}"#
                ].joined(separator: "\n") + "\n"
                try input.fileHandleForWriting.write(contentsOf: Data(requests.utf8))
                try? await Task.sleep(for: .seconds(1))
                try input.fileHandleForWriting.close()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else {
                    return nil
                }
                return parser.parse(lines: text.split(whereSeparator: \.isNewline).map(String.init), now: now)
            } catch {
                if process.isRunning { process.terminate() }
                return nil
            }
        }.value
    }

    public static func defaultExecutableURL(fileManager: FileManager = .default) -> URL? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates.first(where: fileManager.isExecutableFile(atPath:)).map(URL.init(fileURLWithPath:))
    }
}
