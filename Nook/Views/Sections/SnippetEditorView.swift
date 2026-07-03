import SwiftUI

/// Edits a single snippet.
///
/// The snippet is edited through a local `@State` draft so every field is a
/// plain, stable input box (no cursor jumping, no stale values). The draft is
/// written back to the store on change, which persists it with a short
/// debounce — there is no explicit save. The parent gives this view an
/// `.id(snippet.id)` so selecting a different snippet reloads the draft.
struct SnippetEditorView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var draft: Snippet
    @State private var newTag = ""
    @State private var scriptOutput: String?

    init(snippet: Snippet) {
        _draft = State(initialValue: snippet)
    }

    var body: some View {
        Form {
            basicsSection
            contentSection
            if draft.kind == .richText { richTextSection }
            if draft.kind == .image { imageSection }
            optionsSection
            organizationSection
            if draft.kind == .text || draft.kind == .script { previewSection }
        }
        .formStyle(.grouped)
        .onChange(of: draft) { _, updated in
            dependencies.snippetStore.update(updated)
        }
    }

    // MARK: - Sections

    private var basicsSection: some View {
        Section("Basics") {
            LabeledField("Name") {
                TextField("Snippet name", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledField("Trigger") {
                HStack(spacing: 4) {
                    Text(dependencies.settingsStore.settings.triggerPrefix)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("trigger", text: $draft.trigger)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                }
            }
            LabeledField("Type") {
                Picker("Type", selection: $draft.kind) {
                    ForEach(SnippetKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }

    private var contentSection: some View {
        Section(draft.kind == .script ? "Script" : "Replacement") {
            TextEditor(text: $draft.replacement)
                .font(.system(.body, design: draft.kind == .script ? .monospaced : .default))
                .frame(minHeight: 120)
                .overlay(alignment: .topLeading) {
                    if draft.replacement.isEmpty {
                        Text(draft.kind == .script ? "return \"value\";" : "Replacement text…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }

            if draft.kind == .text {
                Text("Use {{variables}} for dynamic values, {{fillIn}} to prompt for input, and | for the cursor position (\\| for a literal pipe).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if draft.kind == .script {
                LabeledField("Language") {
                    Picker("Language", selection: $draft.scriptLanguage) {
                        ForEach(ScriptLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                }
                Text("The script's return value replaces the trigger.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var richTextSection: some View {
        Section("Formatted Content") {
            if let rtf = draft.rtfData,
               let attributed = try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                Text(AttributedString(attributed))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No formatted content captured yet. The plain replacement above is used as a fallback.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Capture Formatted Text from Clipboard") { captureRTF() }
        }
    }

    private var imageSection: some View {
        Section("Image") {
            if let data = draft.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
            } else {
                Text("No image yet. Copy an image, then capture it below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Capture Image from Clipboard") { captureImage() }
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Toggle("Enabled", isOn: $draft.isEnabled)
            Toggle("Favorite", isOn: $draft.isFavorite)
            Toggle("Case sensitive", isOn: $draft.isCaseSensitive)
            Toggle("Whole word only", isOn: $draft.wholeWordOnly)
            LabeledField("Expansion method") {
                Picker("Expansion method", selection: $draft.expansionMethod) {
                    ForEach(ExpansionMethodPreference.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var organizationSection: some View {
        Section("Organization") {
            LabeledField("Folder") {
                Picker("Folder", selection: $draft.folderID) {
                    Text("None").tag(SnippetFolder.ID?.none)
                    ForEach(dependencies.snippetStore.folders.sorted(by: { $0.sortOrder < $1.sortOrder })) { folder in
                        Text(folder.name).tag(SnippetFolder.ID?.some(folder.id))
                    }
                }
                .labelsHidden()
            }
            tagsField
        }
    }

    private var tagsField: some View {
        LabeledField("Tags") {
            VStack(alignment: .leading, spacing: 8) {
                if !draft.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(draft.tags, id: \.self) { tag in
                            TagChip(text: tag) { removeTag(tag) }
                        }
                    }
                }
                HStack {
                    TextField("Add a tag", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTag() }
                    Button("Add") { addTag() }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            switch draft.kind {
            case .text:
                Text(livePreview)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            case .script:
                HStack {
                    Button("Run Preview") { runScriptPreview() }
                    if let scriptOutput {
                        Text(scriptOutput)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Actions

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !draft.tags.contains(tag) else { newTag = ""; return }
        draft.tags.append(tag)
        newTag = ""
    }

    private func removeTag(_ tag: String) {
        draft.tags.removeAll { $0 == tag }
    }

    private func runScriptPreview() {
        do {
            scriptOutput = try dependencies.scriptEngine.run(draft.replacement, language: draft.scriptLanguage)
        } catch {
            scriptOutput = error.localizedDescription
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

/// A label above its control, used to make each editor field self-explanatory.
private struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
        .padding(.vertical, 2)
    }
}

/// A removable tag pill.
private struct TagChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
}

/// Minimal wrapping layout so tag chips flow onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

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
