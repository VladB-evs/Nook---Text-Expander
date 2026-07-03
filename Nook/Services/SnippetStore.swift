import Foundation

/// Source of truth for snippets and folders, with immediate (debounced)
/// JSON auto-save and a change hook the matching engine subscribes to.
@MainActor
@Observable
final class SnippetStore {
    private(set) var snippets: [Snippet] = []
    private(set) var folders: [SnippetFolder] = []

    /// Called after any mutation, once the in-memory state is updated.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let persistence: any SnippetPersisting
    @ObservationIgnored private let logger: DebugLogger?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(persistence: any SnippetPersisting = JSONPersistence(), logger: DebugLogger? = nil) {
        self.persistence = persistence
        self.logger = logger
        load()
    }

    var library: SnippetLibrary {
        SnippetLibrary(snippets: snippets, folders: folders)
    }

    func snippet(withID id: Snippet.ID) -> Snippet? {
        snippets.first { $0.id == id }
    }

    func folder(withID id: SnippetFolder.ID?) -> SnippetFolder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    // MARK: - Mutations

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
        didMutate()
    }

    func update(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        var updated = snippet
        updated.modifiedAt = .now
        snippets[index] = updated
        didMutate()
    }

    func delete(_ ids: Set<Snippet.ID>) {
        snippets.removeAll { ids.contains($0.id) }
        didMutate()
    }

    func addFolder(named name: String) -> SnippetFolder {
        let folder = SnippetFolder(name: name, sortOrder: (folders.map(\.sortOrder).max() ?? -1) + 1)
        folders.append(folder)
        didMutate()
        return folder
    }

    func renameFolder(_ id: SnippetFolder.ID, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = name
        didMutate()
    }

    func deleteFolder(_ id: SnippetFolder.ID) {
        folders.removeAll { $0.id == id }
        for index in snippets.indices where snippets[index].folderID == id {
            snippets[index].folderID = nil
        }
        didMutate()
    }

    /// Merges an imported library: snippets with unseen triggers are added,
    /// snippets with identical IDs are replaced.
    func importLibrary(_ library: SnippetLibrary) {
        let knownFolderIDs = Set(folders.map(\.id))
        for folder in library.folders where !knownFolderIDs.contains(folder.id) {
            folders.append(folder)
        }
        let knownSnippetIDs = Set(snippets.map(\.id))
        for snippet in library.snippets {
            if knownSnippetIDs.contains(snippet.id) {
                update(snippet)
            } else {
                snippets.append(snippet)
            }
        }
        didMutate()
    }

    func replaceLibrary(_ library: SnippetLibrary) {
        snippets = library.snippets
        folders = library.folders
        didMutate()
    }

    // MARK: - Persistence

    private func load() {
        do {
            if let library = try persistence.loadLibrary() {
                snippets = library.snippets
                folders = library.folders
            } else {
                let starter = SnippetStore.starterLibrary()
                snippets = starter.snippets
                folders = starter.folders
                persistNow()
            }
        } catch {
            logger?.log(.error, "Failed to load snippets: \(error.localizedDescription)")
        }
    }

    private func didMutate() {
        onChange?()
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let library = self.library
        saveTask = Task { [persistence, logger] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            do {
                try persistence.saveLibrary(library)
                logger?.log(.storage, "Saved \(library.snippets.count) snippets")
            } catch {
                logger?.log(.error, "Failed to save snippets: \(error.localizedDescription)")
            }
        }
    }

    /// Writes synchronously-ish, used at quit and first launch.
    func persistNow() {
        saveTask?.cancel()
        do {
            try persistence.saveLibrary(library)
        } catch {
            logger?.log(.error, "Failed to save snippets: \(error.localizedDescription)")
        }
    }

    /// A few example snippets so the first launch isn't an empty screen.
    static func starterLibrary() -> SnippetLibrary {
        let examples = SnippetFolder(name: "Examples", sortOrder: 0)
        return SnippetLibrary(
            snippets: [
                Snippet(
                    name: "Email address",
                    trigger: "email",
                    replacement: "hello@example.com",
                    folderID: examples.id
                ),
                Snippet(
                    name: "Today's date",
                    trigger: "date",
                    replacement: "{{date}}",
                    folderID: examples.id
                ),
                Snippet(
                    name: "Meeting note",
                    trigger: "meeting",
                    replacement: "Meeting with {{client}}\nDate: {{date}}\nNotes: |",
                    folderID: examples.id
                ),
                Snippet(
                    name: "Console log",
                    trigger: "log",
                    replacement: "console.log(|)",
                    folderID: examples.id
                ),
                Snippet(
                    name: "Greeting script",
                    trigger: "greet",
                    replacement: #"return `Good ${new Date().getHours() < 12 ? "morning" : "afternoon"}`;"#,
                    kind: .script,
                    folderID: examples.id
                ),
            ],
            folders: [examples]
        )
    }
}
