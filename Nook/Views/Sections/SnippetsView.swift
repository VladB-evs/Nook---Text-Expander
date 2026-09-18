import SwiftUI
import UniformTypeIdentifiers

/// Snippet Studio: responsive list on the left, streamlined editor on the right.
/// Themed with #151514 background and #EDA101 accent color.
struct SnippetsView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var searchText = ""
    @State private var sortOrder = SnippetSearch.SortOrder.name
    @State private var selectedSnippetID: Snippet.ID?
    @State private var importErrorMessage: String?

    var body: some View {
        HSplitView {
            snippetListPane
                .frame(minWidth: 190, idealWidth: 230, maxWidth: 320)
            detailPane
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.nookBackground)
        .navigationTitle(currentTitle)
        .alert("Import Failed", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var currentTitle: String {
        switch dependencies.navigationSelection {
        case .allSnippets:
            return "All Snippets"
        case .favorites:
            return "Favorites"
        case .folder(let id):
            return dependencies.snippetStore.folder(withID: id)?.name ?? "Folder"
        default:
            return "Snippets"
        }
    }

    private var currentFolderID: SnippetFolder.ID? {
        if case .folder(let id) = dependencies.navigationSelection {
            return id
        }
        return nil
    }

    private var visibleSnippets: [Snippet] {
        let store = dependencies.snippetStore
        var snippets = store.snippets
        switch dependencies.navigationSelection {
        case .allSnippets:
            break
        case .favorites:
            snippets = snippets.filter(\.isFavorite)
        case .folder(let id):
            snippets = snippets.filter { $0.folderID == id }
        default:
            break
        }
        snippets = SnippetSearch.filter(snippets, query: searchText, folders: store.folders)
        return SnippetSearch.sort(snippets, by: sortOrder)
    }

    // MARK: - List Pane

    private var snippetListPane: some View {
        VStack(spacing: 0) {
            // Search Bar & Add Button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(Color.nookSecondaryText)
                    TextField("Search…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.nookSecondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))

                Button {
                    addSnippet()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.nookBackground)
                        .frame(width: 26, height: 26)
                        .background(Color.nookAccent, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Create New Snippet (⌘N)")
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Sub-header: Count and Sort Menu
            HStack {
                Text("\(visibleSnippets.count) \(visibleSnippets.count == 1 ? "snippet" : "snippets")")
                    .font(.caption2)
                    .foregroundStyle(Color.nookSecondaryText)

                Spacer()

                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(SnippetSearch.SortOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    Divider()
                    Button("Import Snippets…") { importSnippets() }
                    Button("Export as JSON…") { exportSnippets(format: .json) }
                    Button("Export as YAML…") { exportSnippets(format: .yaml) }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10))
                        Text(sortOrder.displayName)
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.nookSecondaryText)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            Divider()
                .overlay(Color.nookBorder)

            // Snippets List
            if visibleSnippets.isEmpty {
                emptyState
            } else {
                List(visibleSnippets, selection: $selectedSnippetID) { snippet in
                    SnippetRow(
                        snippet: snippet,
                        prefix: dependencies.settingsStore.settings.triggerPrefix
                    )
                    .tag(snippet.id)
                    .contextMenu { rowContextMenu(snippet) }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .onDeleteCommand { deleteSelection(fallback: nil) }
            }
        }
        .background(Color.nookBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "character.cursor.ibeam" : "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(Color.nookAccent.opacity(0.8))

            Text(searchText.isEmpty ? "No snippets yet" : "No matches")
                .font(.headline)
                .foregroundStyle(.white)

            Text(searchText.isEmpty
                 ? "Add a snippet to expand shortcuts as you type."
                 : "Try a different search query.")
                .font(.caption)
                .foregroundStyle(Color.nookSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if searchText.isEmpty {
                Button {
                    addSnippet()
                } label: {
                    Label("Create Snippet", systemImage: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(Color.nookBackground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.nookAccent, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedSnippetID, let snippet = dependencies.snippetStore.snippet(withID: id) {
            SnippetEditorView(snippet: snippet, onDelete: {
                deleteSelection(fallback: id)
            })
            .id(id)
        } else {
            ContentUnavailableView {
                Label("Select a Snippet", systemImage: "text.cursor")
                    .foregroundStyle(.white)
            } description: {
                Text("Choose a snippet from the list or create a new one.")
                    .foregroundStyle(Color.nookSecondaryText)
            } actions: {
                Button {
                    addSnippet()
                } label: {
                    Text("New Snippet")
                        .font(.body.bold())
                        .foregroundStyle(Color.nookBackground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.nookAccent, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.nookBackground)
        }
    }

    // MARK: - Context Menu & Actions

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

    private func addSnippet() {
        var snippet = Snippet(name: "New Snippet")
        if let folderID = currentFolderID {
            snippet.folderID = folderID
        }
        dependencies.snippetStore.add(snippet)
        selectedSnippetID = snippet.id
    }

    private func duplicate(_ snippet: Snippet) {
        var copy = snippet
        copy.id = UUID()
        copy.name = snippet.name.isEmpty ? "Copy" : "\(snippet.name) Copy"
        copy.trigger = snippet.trigger.isEmpty ? "copy" : "\(snippet.trigger)2"
        dependencies.snippetStore.add(copy)
        selectedSnippetID = copy.id
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
        self.selectedSnippetID = nil
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
}

// MARK: - Snippet Row

private struct SnippetRow: View {
    let snippet: Snippet
    let prefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                // Monospaced Trigger Pill in Accent
                Text(prefix + (snippet.trigger.isEmpty ? "…" : snippet.trigger))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(snippet.isEnabled ? Color.nookAccent : Color.nookSecondaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        snippet.isEnabled ? Color.nookAccent.opacity(0.12) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 4)
                    )

                // Title
                Text(snippet.name.isEmpty ? "Untitled" : snippet.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(snippet.isEnabled ? .white : Color.nookSecondaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Icons
                if snippet.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.nookAccent)
                }

                if !snippet.isEnabled {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nookSecondaryText)
                } else if snippet.kind != .text {
                    Image(systemName: kindIcon)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.nookSecondaryText)
                }
            }

            // 1-Line Preview
            Text(previewText)
                .font(.caption2)
                .foregroundStyle(Color.nookSecondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }

    private var previewText: String {
        switch snippet.kind {
        case .text:
            let singleLine = snippet.replacement.replacingOccurrences(of: "\n", with: " ⏎ ")
            return singleLine.isEmpty ? "Empty snippet" : singleLine
        case .script:
            return "JavaScript snippet"
        case .richText:
            return "Rich formatted text"
        case .image:
            return "Image snippet"
        }
    }

    private var kindIcon: String {
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
