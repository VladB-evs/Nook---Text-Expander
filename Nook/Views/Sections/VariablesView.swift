import SwiftUI

/// Variables manager themed in #151514 and #EDA101.
/// Responsive grid with click-to-copy built-in reference and custom variable management.
struct VariablesView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var isAddingVariable = false
    @State private var draftName = ""
    @State private var draftKind = CustomVariableKind.text
    @State private var draftValue = ""
    @State private var exampleSeed = 0
    @State private var copiedVariable: String?

    var body: some View {
        @Bindable var settingsStore = dependencies.settingsStore

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                customVariablesSection(variables: $settingsStore.settings.customVariables)
                Divider().overlay(Color.nookBorder)
                builtInReferenceSection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.nookBackground)
        .navigationTitle("Variables")
        .sheet(isPresented: $isAddingVariable) {
            addVariableSheet(variables: $settingsStore.settings.customVariables)
        }
    }

    // MARK: - Custom Variables Section

    private func customVariablesSection(variables: Binding<[CustomVariable]>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Variables")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Reusable values inserted as {{name}}.")
                        .font(.caption)
                        .foregroundStyle(Color.nookSecondaryText)
                }

                Spacer()

                Button {
                    draftName = ""
                    draftKind = .text
                    draftValue = ""
                    isAddingVariable = true
                } label: {
                    Label("Add Variable", systemImage: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(Color.nookBackground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.nookAccent, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            if variables.wrappedValue.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "curlybraces")
                        .font(.title2)
                        .foregroundStyle(Color.nookSecondaryText)
                    Text("No custom variables yet")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text("Create reusable shortcuts like {{client}} or {{signature}}.")
                        .font(.caption)
                        .foregroundStyle(Color.nookSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))
            } else {
                VStack(spacing: 6) {
                    ForEach(variables.wrappedValue) { variable in
                        HStack(spacing: 8) {
                            Text("{{\(variable.name)}}")
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundStyle(Color.nookAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.nookAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))

                            Text(variable.value)
                                .font(.system(.caption, design: variable.kind == .script ? .monospaced : .default))
                                .foregroundStyle(Color.nookSecondaryText)
                                .lineLimit(1)

                            Spacer()

                            Text(variable.kind.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.nookSecondaryText)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.06), in: Capsule())

                            Button {
                                variables.wrappedValue.removeAll { $0.id == variable.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                    .foregroundStyle(Color.nookSecondaryText)
                            }
                            .buttonStyle(.plain)
                            .help("Delete variable")
                        }
                        .padding(8)
                        .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Built-in Reference

    private var builtInReferenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Built-in Dynamic Variables")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Evaluates at expansion time. Click to copy.")
                        .font(.caption)
                        .foregroundStyle(Color.nookSecondaryText)
                }

                Spacer()

                Button {
                    exampleSeed += 1
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundStyle(Color.nookSecondaryText)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
                refCard(tag: "{{date}}", desc: "YYYY-MM-DD", val: example(for: "date"))
                refCard(tag: "{{time}}", desc: "HH:MM", val: example(for: "time"))
                refCard(tag: "{{datetime}}", desc: "Date & Time", val: example(for: "datetime"))
                refCard(tag: "{{year}}", desc: "Year", val: example(for: "year"))
                refCard(tag: "{{month}}", desc: "Month (01-12)", val: example(for: "month"))
                refCard(tag: "{{day}}", desc: "Day (01-31)", val: example(for: "day"))
                refCard(tag: "{{weekday}}", desc: "Day of week", val: example(for: "weekday"))
                refCard(tag: "{{clipboard}}", desc: "Clipboard", val: "Clipboard text")
                refCard(tag: "{{selection}}", desc: "Selection", val: "Selected text")
                refCard(tag: "{{uuid}}", desc: "UUID", val: example(for: "uuid"))
                refCard(tag: "{{username}}", desc: "User", val: example(for: "username"))
                refCard(tag: "{{hostname}}", desc: "Hostname", val: example(for: "hostname"))
                refCard(tag: "{{random}}", desc: "Random #", val: example(for: "random"))
                refCard(tag: "{{unix}}", desc: "Unix epoch", val: example(for: "unix"))
            }
        }
    }

    private func refCard(tag: String, desc: String, val: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(tag, forType: .string)
            copiedVariable = tag
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if copiedVariable == tag { copiedVariable = nil }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(tag)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Color.nookAccent)
                    Spacer()
                    if copiedVariable == tag {
                        Text("Copied")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.nookAccent)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.nookSecondaryText)
                    }
                }

                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(Color.nookSecondaryText)

                Text(val)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.nookBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Variable Sheet

    private func addVariableSheet(variables: Binding<[CustomVariable]>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Custom Variable")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(Color.nookSecondaryText)
                HStack(spacing: 2) {
                    Text("{{")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.nookSecondaryText)
                    TextField("variableName", text: $draftName)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.nookBorder, lineWidth: 1))
                    Text("}}")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.nookSecondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Type")
                    .font(.caption)
                    .foregroundStyle(Color.nookSecondaryText)
                Picker("Type", selection: $draftKind) {
                    ForEach(CustomVariableKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(draftKind == .script ? "JavaScript Return Code" : "Replacement Text")
                    .font(.caption)
                    .foregroundStyle(Color.nookSecondaryText)
                if draftKind == .script {
                    TextEditor(text: $draftValue)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(height: 70)
                        .padding(4)
                        .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.nookBorder, lineWidth: 1))
                } else {
                    TextField("Value to insert", text: $draftValue)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Color.nookCard, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.nookBorder, lineWidth: 1))
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    isAddingVariable = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.nookSecondaryText)

                Button("Save Variable") {
                    let sanitized = sanitizedName
                    variables.wrappedValue.append(CustomVariable(
                        name: sanitized,
                        value: draftValue,
                        kind: draftKind
                    ))
                    isAddingVariable = false
                }
                .buttonStyle(.plain)
                .font(.body.bold())
                .foregroundStyle(Color.nookBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(canSave ? Color.nookAccent : Color.nookAccent.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                .disabled(!canSave)
            }
        }
        .padding(18)
        .frame(width: 340)
        .background(Color.nookBackground)
    }

    private var sanitizedName: String {
        draftName.filter { !$0.isWhitespace && $0 != "{" && $0 != "}" && $0 != ":" }
    }

    private var canSave: Bool {
        let name = sanitizedName.lowercased()
        guard !name.isEmpty, !VariableResolver.builtInNames.contains(name) else { return false }
        return !dependencies.settingsStore.settings.customVariables.contains { $0.name.lowercased() == name }
    }

    private func example(for name: String) -> String {
        _ = exampleSeed
        switch name {
        case "clipboard": return "clipboard"
        case "selection": return "selection"
        default: return dependencies.variableResolver.resolve(name: name) ?? "val"
        }
    }
}
