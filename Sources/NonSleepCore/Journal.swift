import Foundation

/// Written BEFORE lid mode is switched on and removed only after it is switched off,
/// so a crash or a failed restore is always visible to the next launch and to the backstop.
public struct JournalEntry: Codable, Equatable, Sendable {
    public var lidModeEnabled: Bool
    public var endsAt: Date

    public init(lidModeEnabled: Bool, endsAt: Date) {
        self.lidModeEnabled = lidModeEnabled
        self.endsAt = endsAt
    }
}

public struct Journal: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static var `default`: Journal {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return Journal(url: base.appendingPathComponent("NonSleep/journal.json"))
    }

    public func read() -> JournalEntry? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(JournalEntry.self, from: data)
    }

    public func write(_ entry: JournalEntry) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(entry).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
