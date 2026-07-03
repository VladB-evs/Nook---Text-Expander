import Foundation

/// Application appearance override.
nonisolated enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// How a custom variable produces its value.
nonisolated enum CustomVariableKind: String, Codable, CaseIterable, Sendable {
    case text
    case script

    var displayName: String {
        switch self {
        case .text: "Text"
        case .script: "Script"
        }
    }
}

/// A user-defined variable usable in snippets as `{{name}}`.
///
/// Text variables insert their value verbatim; script variables run their
/// JavaScript source at expansion time and insert the returned value.
nonisolated struct CustomVariable: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var kind: CustomVariableKind
    /// The literal value (`.text`) or the script source (`.script`).
    var value: String

    init(id: UUID = UUID(), name: String = "", value: String = "", kind: CustomVariableKind = .text) {
        self.id = id
        self.name = name
        self.value = value
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        kind = try c.decodeIfPresent(CustomVariableKind.self, forKey: .kind) ?? .text
        value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
    }
}

/// All persisted application settings.
nonisolated struct AppSettings: Codable, Equatable, Sendable {
    /// Characters the user types before every trigger, e.g. ";" in ";src".
    var triggerPrefix: String = ";"
    var isEnabled: Bool = true

    var expandOnSpace: Bool = true
    var expandOnReturn: Bool = true
    var expandOnTab: Bool = true
    /// Additional single-character delimiters that complete a token.
    var customDelimiters: String = ".,:;)]}"

    var suggestionsEnabled: Bool = false
    var launchAtLogin: Bool = false
    var debugLoggingEnabled: Bool = false

    var defaultExpansionMethod: ExpansionMethodPreference = .automatic
    /// Character count above which `.automatic` switches from typing to clipboard paste.
    var typingLengthThreshold: Int = 120
    /// How long to wait before restoring the user's clipboard after a paste expansion.
    var clipboardRestoreDelayMilliseconds: Int = 300
    var rollingBufferCapacity: Int = 64

    var appearance: AppearanceMode = .system
    var customVariables: [CustomVariable] = []

    /// The set of characters that finish a token, honoring the delimiter toggles.
    /// Characters used by the trigger prefix are excluded so the prefix itself
    /// never terminates the token it starts.
    var delimiterCharacters: Set<Character> {
        var set = Set(customDelimiters)
        if expandOnSpace { set.insert(" ") }
        if expandOnReturn { set.insert("\r"); set.insert("\n") }
        if expandOnTab { set.insert("\t") }
        set.subtract(triggerPrefix)
        return set
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        triggerPrefix = try c.decodeIfPresent(String.self, forKey: .triggerPrefix) ?? defaults.triggerPrefix
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        expandOnSpace = try c.decodeIfPresent(Bool.self, forKey: .expandOnSpace) ?? defaults.expandOnSpace
        expandOnReturn = try c.decodeIfPresent(Bool.self, forKey: .expandOnReturn) ?? defaults.expandOnReturn
        expandOnTab = try c.decodeIfPresent(Bool.self, forKey: .expandOnTab) ?? defaults.expandOnTab
        customDelimiters = try c.decodeIfPresent(String.self, forKey: .customDelimiters) ?? defaults.customDelimiters
        suggestionsEnabled = try c.decodeIfPresent(Bool.self, forKey: .suggestionsEnabled) ?? defaults.suggestionsEnabled
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        debugLoggingEnabled = try c.decodeIfPresent(Bool.self, forKey: .debugLoggingEnabled) ?? defaults.debugLoggingEnabled
        defaultExpansionMethod = try c.decodeIfPresent(ExpansionMethodPreference.self, forKey: .defaultExpansionMethod) ?? defaults.defaultExpansionMethod
        typingLengthThreshold = try c.decodeIfPresent(Int.self, forKey: .typingLengthThreshold) ?? defaults.typingLengthThreshold
        clipboardRestoreDelayMilliseconds = try c.decodeIfPresent(Int.self, forKey: .clipboardRestoreDelayMilliseconds) ?? defaults.clipboardRestoreDelayMilliseconds
        rollingBufferCapacity = try c.decodeIfPresent(Int.self, forKey: .rollingBufferCapacity) ?? defaults.rollingBufferCapacity
        appearance = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? defaults.appearance
        customVariables = try c.decodeIfPresent([CustomVariable].self, forKey: .customVariables) ?? defaults.customVariables
    }
}
