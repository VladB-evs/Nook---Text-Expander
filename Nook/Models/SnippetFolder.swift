import Foundation

/// A user-defined group of snippets.
nonisolated struct SnippetFolder: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}

/// The complete persisted snippet collection.
nonisolated struct SnippetLibrary: Codable, Sendable {
    var snippets: [Snippet]
    var folders: [SnippetFolder]

    init(snippets: [Snippet] = [], folders: [SnippetFolder] = []) {
        self.snippets = snippets
        self.folders = folders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        snippets = try c.decodeIfPresent([Snippet].self, forKey: .snippets) ?? []
        folders = try c.decodeIfPresent([SnippetFolder].self, forKey: .folders) ?? []
    }
}
