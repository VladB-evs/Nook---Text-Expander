import SwiftUI
import UniformTypeIdentifiers

/// Snippet library: a filter/search list on the left, editor on the right.
struct SnippetsView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var searchText = ""
    @State private var sortOrder = SnippetSearch.SortOrder.name
    @State private var filter = SnippetFilter.all
    @State private var selectedSnippetID: Snippet.ID?
    @State private var importErrorMessage: String?

    enum SnippetFilter: Hashable {
        case all
        case favorites
        case folder(SnippetFolder.ID)
    }

    var body: some View {
        HSplitView {
            snippetList
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 420)
            detail
                .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar { toolbarContent }
        .navigationTitle("Snippets")
        .alert("Import Failed", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var visibleSnippets: [Snippet] {
        let store = dependencies.snippetStore
        var snippets = store.snippets
        switch filter {
        case .all: break
        case .favorites: snippets = snippets.filter(\.isFavorite)
        case .folder(let id): snippets = snippets.filter { $0.folderID == id }
        }
        snippets = SnippetSearch.filter(snippets, query: searchText, folders: store.folders)
        return SnippetSearch.sort(snippets, by: sortOrder)
    }

    // MARK: - List

    private var snippetList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding([.horizontal, .top], 10)

            Picker("Filter", selection: $filter) {
                Text("All").tag(SnippetFilter.all)
                Text("Favorites").tag(SnippetFilter.favorites)
                ForEach(dependencies.snippetStore.folders.sorted(by: { $0.sortOrder < $1.sortOrder })) { folder in
                    Text(folder.name).tag(SnippetFilter.folder(folder.id))
                }
            }
            .labelsHidden()
            .padding([.horizontal, .top], 10)

            if visibleSnippets.isEmpty {
                emptyList
            } else {
                List(visibleSnippets, selection: $selectedSnippetID) { snippet in
                    SnippetRow(snippet: snippet, prefix: dependencies.settingsStore.settings.triggerPrefix)
                        .tag(snippet.id)
                        .contextMenu { rowContextMenu(snippet) }
                }
                .listStyle(.inset)
                .onDeleteCommand { deleteSelection(fallback: nil) }
            }
        }
    }

    private var emptyList: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "No snippets here yet" : "No matches")
                .foregroundStyle(.secondary)
            if searchText.isEmpty {
                Button("New Snippet") { addSnippet() }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func rowContextMenu(_ snippet: Snippet) -> some View {
        Button(snippet.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            var updated = snippet
            updated.isFavorite.toggle()
            dependencies.snippetStore.update(updated)
        }
        Button(snippet.isEnabled ? "Disable" : "Enable") {
            var updated = snippet
            updated.isEnabled.toggle()
            dependencies.snippetStore.update(updated)
        }
        Divider()
        Button("Duplicate") { duplicate(snippet) }
        Button("Delete", role: .destructive) { deleteSelection(fallback: snippet.id) }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let id = selectedSnippetID, let snippet = dependencies.snippetStore.snippet(withID: id) {
            SnippetEditorView(snippet: snippet)
                .id(id)
        } else {
            ContentUnavailableView {
                Label("No Snippet Selected", systemImage: "text.badge.plus")
            } description: {
                Text("Select a snippet, or create a new one.")
            } actions: {
                Button("New Snippet") { addSnippet() }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button { addSnippet() } label: {
                Label("New Snippet", systemImage: "plus")
            }
            .help("New Snippet")

            Picker("Sort", selection: $sortOrder) {
                ForEach(SnippetSearch.SortOrder.allCases, id: \.self) { order in
                    Text(order.displayName).tag(order)
                }
            }
            .pickerStyle(.menu)
            .help("Sort order")

            Menu {
                Button("New Folder…") { addFolder() }
                if case .folder(let id) = filter {
                    Button("Rename Folder…") { renameFolder(id) }
                    Button("Delete Folder", role: .destructive) { deleteFolder(id) }
                }
                Divider()
                Button("Import…") { importSnippets() }
                Button("Export as JSON…") { exportSnippets(format: .json) }
                Button("Export as YAML…") { exportSnippets(format: .yaml) }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: - Actions

    private func addSnippet() {
        var snippet = Snippet(name: "New Snippet")
        if case .folder(let folderID) = filter {
            snippet.folderID = folderID
        }
        dependencies.snippetStore.add(snippet)
        selectedSnippetID = snippet.id
    }

    private func duplicate(_ snippet: Snippet) {
        var copy = snippet
        copy.id = UUID()
        copy.name = snippet.name.isEmpty ? "Copy" : "\(snippet.name) Copy"
        copy.trigger = snippet.trigger + "2"
        dependencies.snippetStore.add(copy)
        selectedSnippetID = copy.id
    }

    private func addFolder() {
        let name = prompt(title: "New Folder", message: "Folder name:", defaultValue: "New Folder")
        guard let name, !name.isEmpty else { return }
        let folder = dependencies.snippetStore.addFolder(named: name)
        filter = .folder(folder.id)
    }

    private func renameFolder(_ id: SnippetFolder.ID) {
        guard let folder = dependencies.snippetStore.folder(withID: id) else { return }
        let name = prompt(title: "Rename Folder", message: "Folder name:", defaultValue: folder.name)
        guard let name, !name.isEmpty else { return }
        dependencies.snippetStore.renameFolder(id, to: name)
    }

    private func deleteFolder(_ id: SnippetFolder.ID) {
        dependencies.snippetStore.deleteFolder(id)
        filter = .all
    }

    private func deleteSelection(fallback: Snippet.ID?) {
        let ids: Set<Snippet.ID>
        if let selectedSnippetID {
            ids = [selectedSnippetID]
        } else if let fallback {
            ids = [fallback]
        } else {
            return
        }
        dependencies.snippetStore.delete(ids)
        selectedSnippetID = nil
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .yaml, .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let library = try SnippetDocumentCoder.decode(data)
            dependencies.snippetStore.importLibrary(library)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func exportSnippets(format: SnippetDocumentFormat) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Nook Snippets.\(format.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try SnippetDocumentCoder.encode(dependencies.snippetStore.library, format: format)
            try data.write(to: url)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    /// A small modal text prompt for folder names.
    private func prompt(title: String, message: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        return alert.runModal() == .alertFirstButtonReturn
            ? field.stringValue.trimmingCharacters(in: .whitespaces)
            : nil
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let prefix: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(snippet.isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(prefix + snippet.trigger)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(snippet.isEnabled ? .primary : .tertiary)
                    if snippet.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(snippet.name.isEmpty ? snippet.replacement : snippet.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if !snippet.isEnabled {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch snippet.kind {
        case .text: "textformat"
        case .richText: "textformat.alt"
        case .image: "photo"
        case .script: "curlybraces"
        }
    }
}

extension UTType {
    static var yaml: UTType {
        UTType(filenameExtension: "yaml") ?? .plainText
    }
}
