import SwiftUI

/// Guides the user through granting the system permissions Nook needs.
struct PermissionsView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        let permissions = dependencies.permissions

        Form {
            Section {
                Text("Nook watches for triggers as you type and inserts replacements, which requires two macOS privacy permissions. Nook never stores what you type, and it suspends itself automatically inside password fields.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Required") {
                PermissionRow(
                    title: "Accessibility",
                    detail: "Lets Nook remove typed triggers and insert replacements.",
                    granted: permissions.accessibilityGranted,
                    request: { permissions.requestAccessibility() },
                    openSettings: { permissions.openAccessibilitySettings() }
                )
                PermissionRow(
                    title: "Input Monitoring",
                    detail: "Lets Nook see keystrokes so it can detect triggers.",
                    granted: permissions.inputMonitoringGranted,
                    request: { permissions.requestInputMonitoring() },
                    openSettings: { permissions.openInputMonitoringSettings() }
                )
            }

            Section("Optional") {
                LabeledContent {
                    Toggle("", isOn: Binding(
                        get: { permissions.launchAtLoginEnabled },
                        set: { permissions.setLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                } label: {
                    Text("Launch at Login")
                    Text("Start Nook automatically when you log in.")
                }
            }

            Section("Status") {
                LabeledContent("Keyboard monitor") {
                    statusLabel(
                        active: dependencies.keyboardMonitor.isRunning,
                        activeText: "Running",
                        inactiveText: "Not running"
                    )
                }
                LabeledContent("Secure input") {
                    statusLabel(
                        active: !permissions.secureInputActive,
                        activeText: "Inactive",
                        inactiveText: "Active — expansion suspended"
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Permissions")
        .task {
            dependencies.permissions.refresh()
            dependencies.permissions.startPolling()
        }
        .onDisappear {
            dependencies.permissions.stopPolling()
        }
    }

    private func statusLabel(active: Bool, activeText: String, inactiveText: String) -> some View {
        Label(
            active ? activeText : inactiveText,
            systemImage: active ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        )
        .foregroundStyle(active ? .green : .orange)
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let request: () -> Void
    let openSettings: () -> Void

    var body: some View {
        LabeledContent {
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                HStack {
                    Button("Request") { request() }
                    Button("Open System Settings") { openSettings() }
                }
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }
}
