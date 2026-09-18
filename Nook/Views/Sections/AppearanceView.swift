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
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image("MenuBarIcon")
                                .renderingMode(.template)
                                .foregroundStyle(Color.nookText)
                            Text("Active")
                                .foregroundStyle(Color.nookText)
                        }
                        HStack(spacing: 6) {
                            Image("MenuBarIconPaused")
                                .renderingMode(.template)
                                .foregroundStyle(Color.nookSecondaryText)
                            Text("Paused")
                                .foregroundStyle(Color.nookSecondaryText)
                        }
                    }
                    .font(.subheadline)
                }
                Text("The icon switches automatically to show whether expansion is currently active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.nookBackground)
        .navigationTitle("Appearance")
    }
}
