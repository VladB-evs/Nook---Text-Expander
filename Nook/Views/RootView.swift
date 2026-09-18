import SwiftUI

/// Main window interface: modern macOS sidebar navigation driving
/// the snippet studio, variables manager, settings, and about view.
struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        @Bindable var dependencies = dependencies

        NavigationSplitView {
            SidebarView()
        } detail: {
            switch dependencies.navigationSelection {
            case .allSnippets, .favorites, .folder:
                SnippetsView()
            case .variables:
                VariablesView()
            case .settings:
                SettingsView()
            case .about:
                AboutView()
            }
        }
        .onAppear {
            dependencies.permissions.refresh()
        }
    }
}
