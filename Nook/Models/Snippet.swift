import Foundation

/// The kind of content a snippet expands into.
nonisolated enum SnippetKind: String, Codable, CaseIterable, Sendable {
    case text
    case richText
    case image
    case script

    var displayName: String {
        switch self {
        case .text: "Plain Text"
        case .richText: "Rich Text"
        case .image: "Image"
        case .script: "Script"
        }
    }
}

/// How a snippet's content should be delivered into the focused application.
nonisolated enum ExpansionMethodPreference: String, Codable, CaseIterable, Sendable {
    case automatic
    case typing
    case clipboard

    var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .typing: "Simulated Typing"
        case .clipboard: "Clipboard Paste"
        }
    }
}

/// Script languages a script snippet can be written in.
///
/// Only JavaScript ships today; the enum exists so future runners
/// (Swift, Shell, Python, plugins) slot in without model changes.
nonisolated enum ScriptLanguage: String, Codable, CaseIterable, Sendable {
    case javascript

    var displayName: String {
        switch self {
        case .javascript: "JavaScript"
        }
    }
}

/// A single text-expansion rule.
///
/// `trigger` never contains the global trigger prefix — the prefix is an
/// application-level setting applied at match time.
nonisolated struct Snippet: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var trigger: String
    var replacement: String
    var kind: SnippetKind
    var scriptLanguage: ScriptLanguage
    /// RTF data when `kind == .richText`.
    var rtfData: Data?
    /// PNG data when `kind == .image`.
    var imageData: Data?
    var tags: [String]
    var folderID: UUID?
    var isEnabled: Bool
    var isFavorite: Bool
    var isCaseSensitive: Bool
    /// When true the trigger only matches a whole typed token;
    /// when false it may also match the tail of a longer token.
    var wholeWordOnly: Bool
    var expansionMethod: ExpansionMethodPreference
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        trigger: String = "",
        replacement: String = "",
        kind: SnippetKind = .text,
        scriptLanguage: ScriptLanguage = .javascript,
        rtfData: Data? = nil,
        imageData: Data? = nil,
        tags: [String] = [],
        folderID: UUID? = nil,
        isEnabled: Bool = true,
        isFavorite: Bool = false,
        isCaseSensitive: Bool = false,
        wholeWordOnly: Bool = true,
        expansionMethod: ExpansionMethodPreference = .automatic,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.replacement = replacement
        self.kind = kind
        self.scriptLanguage = scriptLanguage
        self.rtfData = rtfData
        self.imageData = imageData
        self.tags = tags
        self.folderID = folderID
        self.isEnabled = isEnabled
        self.isFavorite = isFavorite
        self.isCaseSensitive = isCaseSensitive
        self.wholeWordOnly = wholeWordOnly
        self.expansionMethod = expansionMethod
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        trigger = try c.decode(String.self, forKey: .trigger)
        replacement = try c.decodeIfPresent(String.self, forKey: .replacement) ?? ""
        kind = try c.decodeIfPresent(SnippetKind.self, forKey: .kind) ?? .text
        scriptLanguage = try c.decodeIfPresent(ScriptLanguage.self, forKey: .scriptLanguage) ?? .javascript
        rtfData = try c.decodeIfPresent(Data.self, forKey: .rtfData)
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isCaseSensitive = try c.decodeIfPresent(Bool.self, forKey: .isCaseSensitive) ?? false
        wholeWordOnly = try c.decodeIfPresent(Bool.self, forKey: .wholeWordOnly) ?? true
        expansionMethod = try c.decodeIfPresent(ExpansionMethodPreference.self, forKey: .expansionMethod) ?? .automatic
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .now
    }
}
