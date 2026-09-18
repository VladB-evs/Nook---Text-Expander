import SwiftUI

/// Nook — system-wide text expansion from the menu bar.
///
/// The app has no Dock icon (`LSUIElement`); it lives in the menu bar and
/// opens a single settings/library window on demand.
@main
struct NookApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(dependencies)
        } label: {
            MenuBarLabel()
                .environment(dependencies)
        }

        Window("Nook", id: WindowID.main) {
            RootView()
                .environment(dependencies)
                .preferredColorScheme(dependencies.settingsStore.settings.appearance == .light ? .light : .dark)
                .frame(minWidth: 640, minHeight: 400)
        }
        .defaultSize(width: 820, height: 520)
    }
}

enum WindowID {
    static let main = "main"
}

extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The status item icon. Doubles as the app's launch hook: it is the first
/// view to exist, so its task starts the keyboard monitor.
private struct MenuBarLabel: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(dependencies.isEffectivelyEnabled ? "MenuBarIcon" : "MenuBarIconPaused")
            .renderingMode(.template)
            .task {
                dependencies.start()
                if !dependencies.permissions.accessibilityGranted {
                    openWindow(id: WindowID.main)
                }
            }
    }
}
