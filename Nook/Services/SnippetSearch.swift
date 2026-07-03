import Foundation

/// Filtering and sorting for the snippet list. Simple linear scans — instant
/// at the scale of a personal snippet library, and trivially replaceable
/// with a real index later.
nonisolated enum SnippetSearch {
    enum SortOrder: String, CaseIterable, Sendable {
        case name
        case trigger
        case recentlyModified

        var displayName: String {
            switch self {
            case .name: "Name"
            case .trigger: "Trigger"
            case .recentlyModified: "Recently Modified"
            }
        }
    }

    /// Matches the query against trigger, name, replacement, tags, and the
    /// containing folder's name.
    static func filter(
        _ snippets: [Snippet],
        query: String,
        folders: [SnippetFolder] = []
    ) -> [Snippet] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return snippets }
        let folderNames = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0.name) })
        return snippets.filter { snippet in
            snippet.trigger.localizedCaseInsensitiveContains(trimmed)
                || snippet.name.localizedCaseInsensitiveContains(trimmed)
                || snippet.replacement.localizedCaseInsensitiveContains(trimmed)
                || snippet.tags.contains { $0.localizedCaseInsensitiveContains(trimmed) }
                || (snippet.folderID.flatMap { folderNames[$0] }?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    static func sort(_ snippets: [Snippet], by order: SortOrder) -> [Snippet] {
        switch order {
        case .name:
            snippets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .trigger:
            snippets.sorted { $0.trigger.localizedCaseInsensitiveCompare($1.trigger) == .orderedAscending }
        case .recentlyModified:
            snippets.sorted { $0.modifiedAt > $1.modifiedAt }
        }
    }
}
