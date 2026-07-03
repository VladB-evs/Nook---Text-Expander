import Foundation

/// Source of truth for `AppSettings`, persisted as JSON with debounced saves.
@MainActor
@Observable
final class SettingsStore {
    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            onChange?()
            scheduleSave()
        }
    }

    /// Called after any settings change.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let persistence: any SnippetPersisting
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(persistence: any SnippetPersisting = JSONPersistence()) {
        self.persistence = persistence
        settings = ((try? persistence.loadSettings()) ?? nil) ?? AppSettings()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = settings
        saveTask = Task { [persistence] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            try? persistence.saveSettings(snapshot)
        }
    }

    func persistNow() {
        saveTask?.cancel()
        try? persistence.saveSettings(settings)
    }
}
