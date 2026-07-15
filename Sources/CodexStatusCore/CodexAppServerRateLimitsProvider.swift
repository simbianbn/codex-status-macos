import Foundation

public protocol CodexRateLimitsProviding: Sendable {
    func loadQuota(now: Date) async -> QuotaSnapshot?
}

public struct CodexAppServerRateLimitsProvider: CodexRateLimitsProviding, Sendable {
    private let executableURL: URL?
    private let parser: CodexRateLimitsParser
    private let responseTimeout: TimeInterval

    public init(
        executableURL: URL? = Self.defaultExecutableURL(),
        parser: CodexRateLimitsParser = CodexRateLimitsParser(),
        responseTimeout: TimeInterval = 12
    ) {
        self.executableURL = executableURL
        self.parser = parser
        self.responseTimeout = responseTimeout
    }

    public func loadQuota(now: Date) async -> QuotaSnapshot? {
        guard let executableURL else { return nil }
        let parser = parser
        let responseTimeout = responseTimeout

        return await Task.detached(priority: .utility) {
            let process = Process()
            let input = Pipe()
            let output = Pipe()
            let responseState = RateLimitResponseState()
            let responseWaiter = ResponseWaiter()
            process.executableURL = executableURL
            process.arguments = ["app-server", "--stdio"]
            process.standardInput = input
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                output.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty || responseState.append(data, parser: parser, now: now) {
                        responseWaiter.signal()
                    }
                }
                let requests = [
                    #"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-status","version":"1.0.0"},"capabilities":{"experimentalApi":true}}}"#,
                    #"{"method":"initialized"}"#,
                    #"{"id":2,"method":"account/rateLimits/read","params":null}"#
                ].joined(separator: "\n") + "\n"
                try input.fileHandleForWriting.write(contentsOf: Data(requests.utf8))
                await responseWaiter.wait(timeout: responseTimeout)
                output.fileHandleForReading.readabilityHandler = nil
                try? input.fileHandleForWriting.close()
                if process.isRunning { process.terminate() }
                return responseState.quota
            } catch {
                output.fileHandleForReading.readabilityHandler = nil
                try? input.fileHandleForWriting.close()
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

private final class ResponseWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var isSignaled = false

    func wait(timeout: TimeInterval) async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = lock.withLock {
                if isSignaled { return true }
                self.continuation = continuation
                return false
            }
            if resumeImmediately {
                continuation.resume()
                return
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.signal()
            }
        }
    }

    func signal() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            guard !isSignaled else { return nil }
            isSignaled = true
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume()
    }
}

private final class RateLimitResponseState: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var value: QuotaSnapshot?

    var quota: QuotaSnapshot? {
        lock.withLock { value }
    }

    func append(_ newData: Data, parser: CodexRateLimitsParser, now: Date) -> Bool {
        lock.withLock {
            data.append(newData)
            guard let text = String(data: data, encoding: .utf8) else { return false }
            value = parser.parse(lines: text.split(whereSeparator: \.isNewline).map(String.init), now: now)
            return value != nil
        }
    }
}
