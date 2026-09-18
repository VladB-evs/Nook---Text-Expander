import AppKit
import SwiftUI

/// Sections of the main window's sidebar.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case snippets = "Snippets"
    case variables = "Variables"
    case appearance = "Appearance"
    case permissions = "Permissions"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .snippets: "text.badge.plus"
        case .variables: "curlybraces"
        case .appearance: "paintbrush"
        case .permissions: "lock.shield"
        case .advanced: "wrench.and.screwdriver"
        case .about: "info.circle"
        }
    }
}

/// Composition root: builds every service, wires the change hooks, and owns
/// app-level UI state. Created once at launch and injected into the view
/// hierarchy through the SwiftUI environment.
@MainActor
@Observable
final class AppDependencies {
    let logger: DebugLogger
    let settingsStore: SettingsStore
    let snippetStore: SnippetStore
    let snippetEngine: SnippetEngine
    let variableResolver: VariableResolver
    let scriptEngine: ScriptEngine
    let synthesizer: EventSynthesizer
    let clipboard: ClipboardManager
    let permissions: PermissionsManager
    let suggestions: SuggestionController
    let fillInPresenter: FillInPresenter
    let expansionEngine: ExpansionEngine
    let coordinator: ExpansionCoordinator
    let keyboardMonitor: KeyboardMonitor

    var navigationSelection: NavigationItem = .allSnippets
    var selectedSettingsTab: SettingsTab = .general

    var selectedSection: SettingsSection {
        get {
            switch navigationSelection {
            case .allSnippets, .favorites, .folder:
                return .snippets
            case .variables:
                return .variables
            case .settings(let tab):
                switch tab {
                case .general: return .general
                case .appearance: return .appearance
                case .permissions: return .permissions
                case .advanced: return .advanced
                }
            case .about:
                return .about
            }
        }
        set {
            switch newValue {
            case .snippets:
                navigationSelection = .allSnippets
            case .variables:
                navigationSelection = .variables
            case .general:
                selectedSettingsTab = .general
                navigationSelection = .settings(.general)
            case .appearance:
                selectedSettingsTab = .appearance
                navigationSelection = .settings(.appearance)
            case .permissions:
                selectedSettingsTab = .permissions
                navigationSelection = .settings(.permissions)
            case .advanced:
                selectedSettingsTab = .advanced
                navigationSelection = .settings(.advanced)
            case .about:
                navigationSelection = .about
            }
        }
    }

    init(persistence: any SnippetPersisting = JSONPersistence()) {
        let logger = DebugLogger()
        let settingsStore = SettingsStore(persistence: persistence)
        logger.isEnabled = settingsStore.settings.debugLoggingEnabled

        let snippetStore = SnippetStore(persistence: persistence, logger: logger)
        let snippetEngine = SnippetEngine()
        let scriptEngine = ScriptEngine()
        let synthesizer = EventSynthesizer()
        let clipboard = ClipboardManager(logger: logger)
        let permissions = PermissionsManager()
        let suggestions = SuggestionController()
        let fillInPresenter = FillInPresenter()

        let variableResolver = VariableResolver(
            clipboardText: { clipboard.currentText },
            selectedText: { AccessibilityReader.selectedText() }
        )
        variableResolver.updateCustomVariables(settingsStore.settings.customVariables)
        variableResolver.runScript = { source in
            do {
                return try scriptEngine.run(source, language: .javascript)
            } catch {
                logger.log(.error, "Variable script failed: \(error.localizedDescription)")
                return nil
            }
        }

        let expansionEngine = ExpansionEngine(
            synthesizer: synthesizer,
            clipboard: clipboard,
            resolver: variableResolver,
            scripts: scriptEngine,
            logger: logger,
            currentSettings: { settingsStore.settings }
        )
        expansionEngine.fillInProvider = { names, snippetName in
            await fillInPresenter.requestValues(names: names, snippetName: snippetName)
        }

        let coordinator = ExpansionCoordinator(
            engine: snippetEngine,
            expansionEngine: expansionEngine,
            synthesizer: synthesizer,
            suggestions: suggestions,
            logger: logger,
            currentSettings: { settingsStore.settings }
        )

        let keyboardMonitor = KeyboardMonitor()
        keyboardMonitor.handler = coordinator

        self.logger = logger
        self.settingsStore = settingsStore
        self.snippetStore = snippetStore
        self.snippetEngine = snippetEngine
        self.variableResolver = variableResolver
        self.scriptEngine = scriptEngine
        self.synthesizer = synthesizer
        self.clipboard = clipboard
        self.permissions = permissions
        self.suggestions = suggestions
        self.fillInPresenter = fillInPresenter
        self.expansionEngine = expansionEngine
        self.coordinator = coordinator
        self.keyboardMonitor = keyboardMonitor

        snippetStore.onChange = { [weak self] in self?.rebuildEngine() }
        settingsStore.onChange = { [weak self] in self?.applySettings() }
        permissions.onAccessibilityGranted = { [weak self] in self?.startMonitoringIfPossible() }

        rebuildEngine()
    }

    /// Kicks off keyboard monitoring (or permission polling until granted).
    func start() {
        permissions.refresh()
        if permissions.accessibilityGranted {
            startMonitoringIfPossible()
        } else {
            permissions.requestAccessibility()
            selectedSection = .permissions
            openMainWindow()
        }
        if !permissions.accessibilityGranted {
            permissions.startPolling(stopWhenAccessibilityGranted: true)
        }
    }

    private func startMonitoringIfPossible() {
        guard settingsStore.settings.isEnabled, !keyboardMonitor.isRunning else { return }
        if keyboardMonitor.start() {
            logger.log(.permissions, "Keyboard monitor started")
        }
    }

    private func rebuildEngine() {
        snippetEngine.rebuild(
            snippets: snippetStore.snippets,
            triggerPrefix: settingsStore.settings.triggerPrefix
        )
    }

    private func applySettings() {
        let settings = settingsStore.settings
        logger.isEnabled = settings.debugLoggingEnabled
        variableResolver.updateCustomVariables(settings.customVariables)
        rebuildEngine()
        coordinator.settingsDidChange()

        // The event tap is torn down entirely while Nook is disabled so a
        // disabled Nook costs nothing per keystroke.
        if settings.isEnabled {
            startMonitoringIfPossible()
        } else if keyboardMonitor.isRunning {
            keyboardMonitor.stop()
            coordinator.resetTypingContext()
        }
    }

    /// Whether expansion is live right now (used by the menu bar icon).
    var isEffectivelyEnabled: Bool {
        settingsStore.settings.isEnabled && !coordinator.isPaused && keyboardMonitor.isRunning
    }

    func openMainWindow() {
        // The window scene is opened via the openWindow environment action in
        // views; this fallback brings the app forward for panels and prompts.
        NSApp.activate(ignoringOtherApps: true)
    }

    func quit() {
        snippetStore.persistNow()
        settingsStore.persistNow()
        clipboard.restoreNow()
        NSApp.terminate(nil)
    }
}
