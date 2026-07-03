import SwiftUI

/// Built-in dynamic variables, plus one "Add a Variable" section: name field,
/// value field, add button, and the saved variables listed below in the same
/// style as the built-ins (delete appears on hover).
struct VariablesView: View {
    @Environment(AppDependencies.self) private var dependencies

    /// Bumped by the refresh button to recompute the built-in examples.
    @State private var exampleSeed = 0
    @State private var draftName = ""
    @State private var draftValue = ""

    var body: some View {
        @Bindable var settingsStore = dependencies.settingsStore

        Form {
            builtInSection
            addVariableSection(variables: $settingsStore.settings.customVariables)
        }
        .formStyle(.grouped)
        .navigationTitle("Variables")
    }

    // MARK: - Built-in

    private var builtInSection: some View {
        Section {
            ForEach(VariableResolver.builtInNames, id: \.self) { name in
                LabeledContent("{{\(name)}}") {
                    Text(example(for: name))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.system(.body, design: .monospaced))
            }
        } header: {
            HStack {
                Text("Built-in Variables")
                Spacer()
                Button {
                    exampleSeed += 1
                } label: {
                    Label("Regenerate examples", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Regenerate the example values")
            }
        } footer: {
            Text("Built-in variables are evaluated fresh every time a snippet expands. Use any variable in a snippet as {{name}}.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Add a Variable

    private func addVariableSection(variables: Binding<[CustomVariable]>) -> some View {
        Section {
            LabeledContent("Name") {
                HStack(spacing: 3) {
                    Text("{{")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    TextField("name", text: $draftName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 180)
                    Text("}}")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            LabeledContent("Value") {
                TextField("value to insert", text: $draftValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    .onSubmit { addDraft(to: variables) }
            }

            HStack {
                Spacer()
                Button("Add Variable") { addDraft(to: variables) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddDraft(to: variables.wrappedValue))
            }

            ForEach(variables.wrappedValue) { variable in
                SavedVariableRow(variable: variable) {
                    variables.wrappedValue.removeAll { $0.id == variable.id }
                }
            }
        } header: {
            Text("Add a Variable")
        } footer: {
            Text("Start the value with “return” to run it as JavaScript at expansion time, e.g. return new Date().getFullYear() + 1;")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Logic

    /// Names are referenced as `{{name}}`, so braces, colons and whitespace
    /// aren't allowed inside them.
    private var sanitizedDraftName: String {
        String(draftName.filter { !$0.isWhitespace && $0 != "{" && $0 != "}" && $0 != ":" })
    }

    private func canAddDraft(to variables: [CustomVariable]) -> Bool {
        let name = sanitizedDraftName.lowercased()
        guard !name.isEmpty else { return false }
        guard !VariableResolver.builtInNames.contains(name) else { return false }
        return !variables.contains { $0.name.lowercased() == name }
    }

    private func addDraft(to variables: Binding<[CustomVariable]>) {
        guard canAddDraft(to: variables.wrappedValue) else { return }
        // Values written as a JavaScript `return …` run as scripts at
        // expansion time; anything else is inserted verbatim.
        let isScript = draftValue.trimmingCharacters(in: .whitespaces).hasPrefix("return")
        variables.wrappedValue.append(CustomVariable(
            name: sanitizedDraftName,
            value: draftValue,
            kind: isScript ? .script : .text
        ))
        draftName = ""
        draftValue = ""
    }

    private func example(for name: String) -> String {
        _ = exampleSeed
        switch name {
        case "clipboard": return "current clipboard text"
        case "selection": return "currently selected text"
        default: return dependencies.variableResolver.resolve(name: name) ?? ""
        }
    }
}

/// A saved variable, displayed exactly like the built-in rows; hovering
/// reveals a delete button.
private struct SavedVariableRow: View {
    let variable: CustomVariable
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        LabeledContent("{{\(variable.name)}}") {
            HStack(spacing: 8) {
                Text(variable.value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete variable")
                .opacity(isHovering ? 1 : 0)
            }
        }
        .font(.system(.body, design: .monospaced))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
