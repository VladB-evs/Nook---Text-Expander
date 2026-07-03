import SwiftUI

/// The main window: a sidebar of sections and their detail views.
struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        @Bindable var dependencies = dependencies
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $dependencies.selectedSection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
        } detail: {
            switch dependencies.selectedSection {
            case .general: GeneralSettingsView()
            case .snippets: SnippetsView()
            case .variables: VariablesView()
            case .appearance: AppearanceView()
            case .permissions: PermissionsView()
            case .advanced: AdvancedView()
            case .about: AboutView()
            }
        }
        .navigationTitle("Nook")
        .onAppear {
            dependencies.permissions.refresh()
        }
    }
}
