import SwiftUI

struct AppearanceView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        @Bindable var settingsStore = dependencies.settingsStore

        Form {
            Section("Window") {
                Picker("Appearance", selection: $settingsStore.settings.appearance) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                LabeledContent("Menu bar icon") {
                    HStack(spacing: 12) {
                        Label("Active", systemImage: "character.cursor.ibeam")
                        Label("Paused", systemImage: "pause.circle")
                    }
                    .foregroundStyle(.secondary)
                }
                Text("The icon switches automatically to show whether expansion is currently active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }
}
