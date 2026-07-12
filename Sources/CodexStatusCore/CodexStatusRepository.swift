import Foundation

public struct CodexStatusRepository: Sendable {
    public let sessionsRoot: URL
    private let parser: CodexSessionParser
    private let maximumFiles: Int

    public init(
        sessionsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true),
        maximumFiles: Int = 12,
        parser: CodexSessionParser = CodexSessionParser()
    ) {
        self.sessionsRoot = sessionsRoot
        self.maximumFiles = maximumFiles
        self.parser = parser
    }

    public func loadSnapshot(now: Date = Date()) async -> CodexSnapshot {
        let files = newestSessionFiles()
        guard !files.isEmpty else {
            return .unavailable(now: now, message: "No session files were found in ~/.codex/sessions.")
        }

        var selectedQuota: (value: QuotaSnapshot, source: String)?
        var selectedActivity = TaskActivity()
        for file in files {
            guard let lines = recentLines(from: file.url) else { continue }
            let snapshot = parser.parse(lines: lines, now: now)
            if let quota = snapshot.quota,
               selectedQuota == nil || quota.observedAt >= selectedQuota!.value.observedAt {
                selectedQuota = (quota, file.url.path)
            }
            if let observedAt = snapshot.activity.observedAt,
               selectedActivity.observedAt == nil || observedAt >= selectedActivity.observedAt! {
                selectedActivity = snapshot.activity
            }
        }

        let stale = selectedQuota.map { now.timeIntervalSince($0.value.observedAt) > 900 } ?? false
        return CodexSnapshot(
            quota: selectedQuota?.value,
            activity: selectedActivity,
            loadedAt: now,
            sourcePath: selectedQuota?.source,
            errorMessage: selectedQuota == nil ? "No verified Codex quota data was found." : nil,
            isStale: stale
        )
    }

    private func recentLines(from url: URL, maximumBytes: UInt64 = 1_048_576) -> [String]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return nil }
        let offset = end > maximumBytes ? end - maximumBytes : 0
        do {
            try handle.seek(toOffset: offset)
            let data = try handle.readToEnd() ?? Data()
            guard let contents = String(data: data, encoding: .utf8) else { return nil }
            var lines = contents.split(whereSeparator: \.isNewline).map(String.init)
            if offset > 0, !lines.isEmpty {
                lines.removeFirst()
            }
            return lines
        } catch {
            return nil
        }
    }

    private func newestSessionFiles() -> [(url: URL, modifiedAt: Date)] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [(URL, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else {
                continue
            }
            files.append((url, values.contentModificationDate ?? .distantPast))
        }
        return Array(files.sorted { $0.1 > $1.1 }.prefix(maximumFiles))
    }
}
