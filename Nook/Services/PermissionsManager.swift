import AppKit
import Carbon.HIToolbox
import ServiceManagement

/// Tracks the system permissions Nook needs and helps the user grant them.
@MainActor
@Observable
final class PermissionsManager {
    private(set) var accessibilityGranted = false
    private(set) var inputMonitoringGranted = false
    private(set) var launchAtLoginEnabled = false
    private(set) var secureInputActive = false

    @ObservationIgnored private var pollTask: Task<Void, Never>?

    /// Called whenever a refresh discovers accessibility was just granted,
    /// so the keyboard monitor can be (re)started.
    @ObservationIgnored var onAccessibilityGranted: (@MainActor () -> Void)?

    init() {
        refresh()
    }

    var allGranted: Bool { accessibilityGranted && inputMonitoringGranted }

    func refresh() {
        let wasGranted = accessibilityGranted
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        secureInputActive = IsSecureEventInputEnabled()
        if !wasGranted && accessibilityGranted {
            onAccessibilityGranted?()
        }
    }

    /// Polls so the UI and the keyboard monitor react as soon as the user
    /// flips a switch in System Settings. With
    /// `stopWhenAccessibilityGranted` the task ends itself once the monitor
    /// can run, so no timer is left ticking in the background.
    func startPolling(stopWhenAccessibilityGranted: Bool = false) {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self else { return }
                self.refresh()
                if stopWhenAccessibilityGranted && self.accessibilityGranted {
                    self.pollTask = nil
                    return
                }
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Status is re-read below; the toggle simply reflects reality.
        }
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
