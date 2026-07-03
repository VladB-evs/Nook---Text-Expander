import SwiftUI

/// Contents of the status item's menu.
struct MenuBarView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let isEnabled = dependencies.settingsStore.settings.isEnabled

        Button("Open Nook") {
            open(section: .snippets)
        }

        Divider()

        Button(isEnabled ? "Disable" : "Enable") {
            dependencies.settingsStore.settings.isEnabled.toggle()
            if dependencies.settingsStore.settings.isEnabled {
                dependencies.coordinator.resume()
            }
        }

        if dependencies.coordinator.isPaused {
            Button("Resume") {
                dependencies.coordinator.resume()
            }
        } else if isEnabled {
            Menu("Pause") {
                Button("5 Minutes") { dependencies.coordinator.pause(for: 5 * 60) }
                Button("15 Minutes") { dependencies.coordinator.pause(for: 15 * 60) }
                Button("1 Hour") { dependencies.coordinator.pause(for: 60 * 60) }
            }
        }

        Divider()

        Button("Settings…") {
            open(section: .general)
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Nook") {
            dependencies.quit()
        }
        .keyboardShortcut("q")
    }

    private func open(section: SettingsSection) {
        dependencies.selectedSection = section
        openWindow(id: WindowID.main)
        NSApp.activate(ignoringOtherApps: true)
    }
}
