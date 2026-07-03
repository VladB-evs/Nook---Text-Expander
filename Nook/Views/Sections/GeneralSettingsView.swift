import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies

    // Local copies of the text settings. Editing goes through these so the
    // fields stay in sync even when input is sanitized (a plain sanitizing
    // binding can leave the field showing rejected characters).
    @State private var prefixText = ""
    @State private var delimiterText = ""
    @State private var isLoaded = false

    var body: some View {
        @Bindable var settingsStore = dependencies.settingsStore

        Form {
            Section {
                Toggle("Enable Nook", isOn: $settingsStore.settings.isEnabled)
                Toggle("Launch at login", isOn: Binding(
                    get: { dependencies.permissions.launchAtLoginEnabled },
                    set: { dependencies.permissions.setLaunchAtLogin($0) }
                ))
            }

            Section {
                LabeledContent("Prefix") {
                    TextField(" ", text: $prefixText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 90)
                }
            } header: {
                Text("Trigger Prefix")
            } footer: {
                Text("Type this before a trigger, e.g. \(prefixText.isEmpty ? ";" : prefixText)src — it applies to every snippet. Use any symbols you like (;  :  /  #  @  ::  //  !!). Letters, numbers, and spaces are not allowed. Just type it and it will autosave :D")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Space", isOn: $settingsStore.settings.expandOnSpace)
                Toggle("Return", isOn: $settingsStore.settings.expandOnReturn)
                Toggle("Tab", isOn: $settingsStore.settings.expandOnTab)
                LabeledContent("Other characters") {
                    TextField(" ", text: $delimiterText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 160)
                }
            } header: {
                Text("Expand After")
            } footer: {
                Text("A snippet expands the moment you finish its trigger with one of the keys above, or type any character listed in “Other characters”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show snippet suggestions while typing", isOn: $settingsStore.settings.suggestionsEnabled)
            } header: {
                Text("Suggestions")
            } footer: {
                Text("Shows a small popup when several triggers match what you're typing. Navigate with ↑ ↓, accept with Return, dismiss with Esc.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .onAppear {
            guard !isLoaded else { return }
            prefixText = settingsStore.settings.triggerPrefix
            delimiterText = settingsStore.settings.customDelimiters
            isLoaded = true
        }
        .onChange(of: prefixText) { _, newValue in
            // Only symbols: letters/digits would collide with trigger names,
            // whitespace would collide with delimiters.
            let sanitized = String(newValue.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace })
            if sanitized != newValue {
                prefixText = sanitized
            }
            settingsStore.settings.triggerPrefix = sanitized
        }
        .onChange(of: delimiterText) { _, newValue in
            let sanitized = String(newValue.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace })
            if sanitized != newValue {
                delimiterText = sanitized
            }
            settingsStore.settings.customDelimiters = sanitized
        }
    }
}
