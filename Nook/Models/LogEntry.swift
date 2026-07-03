import Foundation

nonisolated enum LogCategory: String, Sendable, CaseIterable {
    case trigger = "Trigger"
    case expansion = "Expansion"
    case clipboard = "Clipboard"
    case script = "Script"
    case permissions = "Permissions"
    case storage = "Storage"
    case error = "Error"
}

/// One line in the optional debug console.
nonisolated struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let category: LogCategory
    let message: String
    /// Elapsed time in milliseconds, when the entry measures an operation.
    let durationMilliseconds: Double?

    init(date: Date = .now, category: LogCategory, message: String, durationMilliseconds: Double? = nil) {
        self.date = date
        self.category = category
        self.message = message
        self.durationMilliseconds = durationMilliseconds
    }
}
