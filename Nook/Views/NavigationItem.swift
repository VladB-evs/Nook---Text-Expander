import Foundation

/// Primary navigation selection in the main window's sidebar.
enum NavigationItem: Hashable, Sendable {
    case allSnippets
    case favorites
    case folder(SnippetFolder.ID)
    case variables
    case settings(SettingsTab)
    case about
}

/// Tabs available in the unified Settings view.
enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case appearance = "Appearance"
    case permissions = "Permissions"
    case advanced = "Advanced"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .permissions: "lock.shield"
        case .advanced: "wrench.and.screwdriver"
        }
    }
}
