import SwiftUI

/// Settings view with responsive tabs themed in #151514 and #EDA101.
struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        @Bindable var dependencies = dependencies

        VStack(spacing: 0) {
            Picker("Settings Tab", selection: $dependencies.selectedSettingsTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.symbol).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .overlay(Color.nookBorder)

            switch dependencies.selectedSettingsTab {
            case .general:
                GeneralSettingsView()
            case .appearance:
                AppearanceView()
            case .permissions:
                PermissionsView()
            case .advanced:
                AdvancedView()
            }
        }
        .background(Color.nookBackground)
        .navigationTitle("Settings — \(dependencies.selectedSettingsTab.rawValue)")
    }
}
