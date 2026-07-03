import Foundation

/// Abstraction over the snippet storage backend.
///
/// The shipping implementation writes pretty-printed JSON; the protocol keeps
/// the door open for SQLite or cloud sync without touching callers.
nonisolated protocol SnippetPersisting: Sendable {
    func loadLibrary() throws -> SnippetLibrary?
    func saveLibrary(_ library: SnippetLibrary) throws
    func loadSettings() throws -> AppSettings?
    func saveSettings(_ settings: AppSettings) throws
}

/// JSON files in `~/Library/Application Support/Nook/`.
nonisolated struct JSONPersistence: SnippetPersisting {
    let directory: URL

    static var defaultDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nook", isDirectory: true)
    }

    init(directory: URL = JSONPersistence.defaultDirectory) {
        self.directory = directory
    }

    private var libraryURL: URL { directory.appendingPathComponent("snippets.json") }
    private var settingsURL: URL { directory.appendingPathComponent("settings.json") }

    func loadLibrary() throws -> SnippetLibrary? {
        try load(SnippetLibrary.self, from: libraryURL)
    }

    func saveLibrary(_ library: SnippetLibrary) throws {
        try save(library, to: libraryURL)
    }

    func loadSettings() throws -> AppSettings? {
        try load(AppSettings.self, from: settingsURL)
    }

    func saveSettings(_ settings: AppSettings) throws {
        try save(settings, to: settingsURL)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try Self.decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
