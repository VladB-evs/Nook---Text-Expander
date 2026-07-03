import Foundation
import os

/// In-memory ring buffer backing the optional debug console.
///
/// Logging is a no-op unless the user enables it in Advanced settings, so the
/// hot path pays only a boolean check.
@MainActor
@Observable
final class DebugLogger {
    var isEnabled = false
    private(set) var entries: [LogEntry] = []
    private let maximumEntries = 500
    private let systemLog = os.Logger(subsystem: "vladinc.Nook", category: "Nook")

    func log(_ category: LogCategory, _ message: String, durationMilliseconds: Double? = nil) {
        guard isEnabled else { return }
        entries.append(LogEntry(category: category, message: message, durationMilliseconds: durationMilliseconds))
        if entries.count > maximumEntries {
            entries.removeFirst(entries.count - maximumEntries)
        }
        if let durationMilliseconds {
            systemLog.debug("[\(category.rawValue)] \(message) (\(durationMilliseconds, format: .fixed(precision: 2)) ms)")
        } else {
            systemLog.debug("[\(category.rawValue)] \(message)")
        }
    }

    func clear() {
        entries.removeAll()
    }
}
