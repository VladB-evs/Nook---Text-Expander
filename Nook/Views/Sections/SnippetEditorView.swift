import SwiftUI

/// Streamlined, responsive snippet editor themed in #151514 and #EDA101.
/// Flexes gracefully with window resize with zero clipping.
struct SnippetEditorView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var draft: Snippet
    var onDelete: (() -> Void)?

    @State private var newTag = ""
    @State private var scriptOutput: String?
    @State private var showOptions = false
    @State private var showDeleteConfirm = false
    @State private var showPromptFieldAlert = false
    @State private var promptFieldName = ""

    init(snippet: Snippet, onDelete: (() -> Void)? = nil) {
        _draft = State(initialValue: snippet)
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerRow

                Divider()
                    .overlay(Color.nookBorder)

                triggerBlock

                contentBlock

                helperToolbar

                if draft.kind == .text && !draft.replacement.isEmpty {
                    livePreviewBox
                }

                Divider()
                    .overlay(Color.nookBorder)

                moreOptionsDisclosure
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.nookBackground)
        .onChange(of: draft) { _, updated in
            dependencies.snippetStore.update(updated)
        }
        .confirmationDialog(
            "Delete Snippet",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Snippet", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete “\(draft.name.isEmpty ? draft.trigger : draft.name)”? This cannot be undone.")
        }
        .alert("Ask for Input at Expansion", isPresented: $showPromptFieldAlert) {
            TextField("Field Name (e.g. client)", text: $promptFieldName)
            Button("Cancel", role: .cancel) {}
            Button("Insert") {
                let trimmed = promptFieldName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    insertText("{{\(trimmed)}}")
                }
            }
        } message: {
            Text("Nook will pop up a quick prompt for this value when the snippet expands.")
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField("Snippet Name", text: $draft.name)
                .font(.title3.bold())
                .textFieldStyle(.plain)
                .foregroundStyle(.white)

            Spacer(minLength: 6)

            // Favorite button
            Button {
                draft.isFavorite.toggle()
            } label: {
                Image(systemName: draft.isFavorite ? "star.fill" : "star")
                    .font(.body)
                    .foregroundStyle(draft.isFavorite ? Color.nookAccent : Color.nookSecondaryText)
            }
            .buttonStyle(.plain)
            .help(draft.isFavorite ? "Remove Favorite" : "Add Favorite")

            // Enabled toggle switch
            Toggle("", isOn: $draft.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.nookAccent)
                .help(draft.isEnabled ? "Snippet is active" : "Snippet is paused")

            // Delete button
            if onDelete != nil {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(Color.nookSecondaryText)
                }
                .buttonStyle(.plain)
                .help("Delete snippet")
            }
        }
    }

    // MARK: - Trigger Input

    private var triggerBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("SHORTCUT TRIGGER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.nookSecondaryText)

            HStack(spacing: 0) {
                Text(dependencies.settingsStore.settings.triggerPrefix)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(Color.nookBackground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.nookAccent)

                TextField("shortcut (e.g. email)", text: $draft.trigger)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))
        }
    }

    // MARK: - Content Editor

    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("EXPANSION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.nookSecondaryText)

                Spacer()

                Menu {
                    ForEach(SnippetKind.allCases, id: \.self) { kind in
                        Button(kind.displayName) { draft.kind = kind }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(draft.kind.displayName)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                    }
                    .font(.caption)
                    .foregroundStyle(Color.nookSecondaryText)
                }
                .menuStyle(.borderlessButton)
            }

            switch draft.kind {
            case .text:
                textCanvas
            case .script:
                scriptCanvas
            case .richText:
                richTextCanvas
            case .image:
                imageCanvas
            }
        }
    }

    private var textCanvas: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $draft.replacement)
                .font(.system(.body, design: .default))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 120)
                .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))

            if draft.replacement.isEmpty {
                Text("Type replacement text…")
                    .font(.body)
                    .foregroundStyle(Color.nookSecondaryText.opacity(0.6))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
    }

    private var scriptCanvas: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draft.replacement)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 110)
                    .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))

                if draft.replacement.isEmpty {
                    Text("// JavaScript return value is expanded\nreturn \"Today is \" + new Date().toDateString();")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.nookSecondaryText.opacity(0.6))
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Button {
                    runScriptPreview()
                } label: {
                    Label("Test Script", systemImage: "play.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.nookBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.nookAccent, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                if let scriptOutput {
                    Text(scriptOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
        }
    }

    private var richTextCanvas: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let rtf = draft.rtfData,
               let attributed = try? NSAttributedString(
                data: rtf,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
               ) {
                Text(AttributedString(attributed))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))
            } else {
                Text("No formatted content captured yet.")
                    .font(.caption)
                    .foregroundStyle(Color.nookSecondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))
            }

            Button {
                captureRTF()
            } label: {
                Label("Paste Rich Text from Clipboard", systemImage: "doc.on.clipboard")
                    .font(.caption)
                    .foregroundStyle(Color.nookAccent)
            }
            .buttonStyle(.plain)
        }
    }

    private var imageCanvas: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let data = draft.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))
            } else {
                Text("No image captured yet.")
                    .font(.caption)
                    .foregroundStyle(Color.nookSecondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))
            }

            Button {
                captureImage()
            } label: {
                Label("Paste Image from Clipboard", systemImage: "photo.badge.arrow.down")
                    .font(.caption)
                    .foregroundStyle(Color.nookAccent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helper Toolbar

    private var helperToolbar: some View {
        HStack(spacing: 8) {
            Menu {
                Section("Date & Time") {
                    Button("Date (YYYY-MM-DD)") { insertText("{{date}}") }
                    Button("Time (HH:MM)") { insertText("{{time}}") }
                    Button("Date & Time") { insertText("{{datetime}}") }
                    Button("Year") { insertText("{{year}}") }
                    Button("Weekday") { insertText("{{weekday}}") }
                }

                Section("System") {
                    Button("Clipboard Text") { insertText("{{clipboard}}") }
                    Button("Selected Text") { insertText("{{selection}}") }
                    Button("Random UUID") { insertText("{{uuid}}") }
                    Button("Username") { insertText("{{username}}") }
                }

                if !dependencies.settingsStore.settings.customVariables.isEmpty {
                    Section("Custom Variables") {
                        ForEach(dependencies.settingsStore.settings.customVariables) { v in
                            Button("{{\(v.name)}}") { insertText("{{\(v.name)}}") }
                        }
                    }
                }

                Section("Interactive") {
                    Button("Prompt for Fill-in…") {
                        promptFieldName = ""
                        showPromptFieldAlert = true
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "curlybraces")
                    Text("Variable")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.nookAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.nookAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)

            Button {
                insertText("|")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "character.cursor.ibeam")
                    Text("Cursor Stop")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.nookSecondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Inserts '|'. The cursor jumps here after expansion.")

            Spacer()
        }
    }

    // MARK: - Live Preview Box

    private var livePreviewBox: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("PREVIEW")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.nookSecondaryText)

            Text(livePreview)
                .font(.system(.caption, design: .default))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))
        }
    }

    // MARK: - More Options

    private var moreOptionsDisclosure: some View {
        DisclosureGroup(isExpanded: $showOptions) {
            VStack(alignment: .leading, spacing: 12) {
                // Folder
                HStack {
                    Text("Folder")
                        .font(.caption)
                        .foregroundStyle(Color.nookSecondaryText)
                        .frame(width: 100, alignment: .leading)

                    Picker("Folder", selection: $draft.folderID) {
                        Text("None").tag(SnippetFolder.ID?.none)
                        ForEach(dependencies.snippetStore.folders.sorted(by: { $0.sortOrder < $1.sortOrder })) { f in
                            Text(f.name).tag(SnippetFolder.ID?.some(f.id))
                        }
                    }
                    .labelsHidden()
                }

                // Delivery Method
                HStack {
                    Text("Delivery")
                        .font(.caption)
                        .foregroundStyle(Color.nookSecondaryText)
                        .frame(width: 100, alignment: .leading)

                    Picker("Delivery", selection: $draft.expansionMethod) {
                        ForEach(ExpansionMethodPreference.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .labelsHidden()
                }

                // Matching Toggles
                HStack(spacing: 16) {
                    Toggle("Case sensitive", isOn: $draft.isCaseSensitive)
                        .font(.caption)
                        .foregroundStyle(Color.nookSecondaryText)
                    Toggle("Whole word only", isOn: $draft.wholeWordOnly)
                        .font(.caption)
                        .foregroundStyle(Color.nookSecondaryText)
                }

                // Tags
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundStyle(Color.nookSecondaryText)

                    if !draft.tags.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(draft.tags, id: \.self) { tag in
                                HStack(spacing: 3) {
                                    Text(tag)
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                    Button {
                                        draft.tags.removeAll { $0 == tag }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8))
                                            .foregroundStyle(Color.nookSecondaryText)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.nookCardHover, in: Capsule())
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        TextField("Add tag…", text: $newTag)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.nookBorder, lineWidth: 1))
                            .onSubmit { addTag() }

                        Button("Add") { addTag() }
                            .font(.caption)
                            .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("More Options")
                    .font(.caption.bold())
                    .foregroundStyle(Color.nookSecondaryText)
                Spacer()
                Text(optionsSummary)
                    .font(.caption2)
                    .foregroundStyle(Color.nookSecondaryText.opacity(0.8))
            }
        }
    }

    private var optionsSummary: String {
        var parts: [String] = []
        if let folderID = draft.folderID, let f = dependencies.snippetStore.folder(withID: folderID) {
            parts.append(f.name)
        }
        if !draft.tags.isEmpty {
            parts.append("\(draft.tags.count) tags")
        }
        if draft.isCaseSensitive {
            parts.append("Case sensitive")
        }
        return parts.isEmpty ? "Default" : parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func insertText(_ text: String) {
        draft.replacement.append(text)
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !draft.tags.contains(tag) else { newTag = ""; return }
        draft.tags.append(tag)
        newTag = ""
    }

    private func runScriptPreview() {
        do {
            scriptOutput = try dependencies.scriptEngine.run(draft.replacement, language: draft.scriptLanguage)
        } catch {
            scriptOutput = "Error: \(error.localizedDescription)"
        }
    }

    private var livePreview: String {
        let template = ExpansionTemplate(parsing: draft.replacement)
        let resolved = template.render { name, argument in
            dependencies.variableResolver.resolve(name: name, argument: argument) ?? "⟨\(name)⟩"
        }
        var text = resolved.text
        if let first = resolved.cursorOffsets.first {
            let index = text.index(text.startIndex, offsetBy: min(first, text.count))
            text.insert(contentsOf: "⌶", at: index)
        }
        return text.isEmpty ? " " : text
    }

    private func captureRTF() {
        let pasteboard = NSPasteboard.general
        guard let rtf = pasteboard.data(forType: .rtf) else { return }
        draft.rtfData = rtf
        if let plain = pasteboard.string(forType: .string), draft.replacement.isEmpty {
            draft.replacement = plain
        }
    }

    private func captureImage() {
        let pasteboard = NSPasteboard.general
        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }
        draft.imageData = png
    }
}

/// Minimal wrapping layout so tag chips flow onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

