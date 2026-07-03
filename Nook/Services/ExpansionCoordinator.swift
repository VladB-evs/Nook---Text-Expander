import AppKit
import Carbon.HIToolbox

/// Routes raw keystrokes through the rolling buffer, the snippet engine, and
/// the expansion pipeline. Also owns runtime enablement (pause) and the
/// post-expansion placeholder session.
@MainActor
@Observable
final class ExpansionCoordinator: KeyEventHandling {
    private(set) var pausedUntil: Date?

    @ObservationIgnored private var buffer: RollingBuffer
    @ObservationIgnored private var placeholderSession: PlaceholderSession?
    @ObservationIgnored private var appSwitchObserver: NSObjectProtocol?

    // Settings-derived state, cached so the per-keystroke path does no
    // recomputation. Refreshed via settingsDidChange().
    @ObservationIgnored private var delimiters: Set<Character> = []
    @ObservationIgnored private var triggerPrefix = ";"
    @ObservationIgnored private var expansionEnabled = true
    @ObservationIgnored private var suggestionsEnabled = false

    @ObservationIgnored private let engine: SnippetEngine
    @ObservationIgnored private let expansionEngine: ExpansionEngine
    @ObservationIgnored private let synthesizer: any EventSynthesizing
    @ObservationIgnored private let suggestions: SuggestionController
    @ObservationIgnored private let logger: DebugLogger
    @ObservationIgnored private let currentSettings: @MainActor () -> AppSettings

    init(
        engine: SnippetEngine,
        expansionEngine: ExpansionEngine,
        synthesizer: any EventSynthesizing,
        suggestions: SuggestionController,
        logger: DebugLogger,
        currentSettings: @escaping @MainActor () -> AppSettings
    ) {
        self.engine = engine
        self.expansionEngine = expansionEngine
        self.synthesizer = synthesizer
        self.suggestions = suggestions
        self.logger = logger
        self.currentSettings = currentSettings
        self.buffer = RollingBuffer(capacity: currentSettings().rollingBufferCapacity)
        settingsDidChange()

        suggestions.onAccept = { [weak self] snippet, typedLength in
            self?.acceptSuggestion(snippet, typedLength: typedLength)
        }
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resetTypingContext()
            }
        }
    }

    /// Re-reads the settings snapshot. Called by the composition root
    /// whenever settings change.
    func settingsDidChange() {
        let settings = currentSettings()
        delimiters = settings.delimiterCharacters
        triggerPrefix = settings.triggerPrefix
        expansionEnabled = settings.isEnabled
        suggestionsEnabled = settings.suggestionsEnabled
        if buffer.capacity != settings.rollingBufferCapacity {
            buffer = RollingBuffer(capacity: settings.rollingBufferCapacity)
        }
        if !suggestionsEnabled {
            suggestions.hide()
        }
    }

    // MARK: - Pause

    var isPaused: Bool {
        if let pausedUntil, pausedUntil > .now { return true }
        return false
    }

    func pause(for interval: TimeInterval) {
        pausedUntil = Date(timeIntervalSinceNow: interval)
        resetTypingContext()
    }

    func resume() {
        pausedUntil = nil
    }

    /// True when expansions should currently happen.
    var isActive: Bool {
        expansionEnabled && !isPaused
    }

    func resetTypingContext() {
        buffer.reset()
        placeholderSession = nil
        suggestions.hide()
    }

    // MARK: - KeyEventHandling

    func handleMouseDown() {
        resetTypingContext()
    }

    func handleKeyDown(keyCode: Int64, characters: String, flags: CGEventFlags) -> Bool {
        guard isActive else { return false }

        // Never observe or expand while a password field has the keyboard.
        if IsSecureEventInputEnabled() {
            resetTypingContext()
            return false
        }

        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            resetTypingContext()
            return false
        }

        if handlePlaceholderNavigation(keyCode: keyCode, flags: flags) {
            return true
        }
        if handleSuggestionNavigation(keyCode: keyCode) {
            return true
        }

        switch Int(keyCode) {
        case kVK_Delete:
            buffer.deleteLast()
            refreshSuggestions()
            return false
        case kVK_ForwardDelete, kVK_Escape, kVK_LeftArrow, kVK_RightArrow,
             kVK_UpArrow, kVK_DownArrow, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown:
            resetTypingContext()
            return false
        default:
            break
        }

        guard !characters.isEmpty else { return false }
        return process(characters: characters, keyCode: keyCode, flags: flags)
    }

    /// Feeds typed characters into the buffer; returns true when the event
    /// completed a trigger and must be swallowed.
    private func process(characters: String, keyCode: Int64, flags: CGEventFlags) -> Bool {
        for character in characters {
            if delimiters.contains(character) {
                let token = buffer.trailingToken(separators: delimiters)
                if let match = engine.match(token: token) {
                    buffer.reset()
                    suggestions.hide()
                    startExpansion(match, delimiter: DelimiterKey(keyCode: keyCode, flagsRawValue: flags.rawValue))
                    return true
                }
                buffer.append(character)
            } else {
                buffer.append(character)
            }
        }
        refreshSuggestions()
        return false
    }

    private func startExpansion(_ match: SnippetMatch, delimiter: DelimiterKey?) {
        placeholderSession = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.placeholderSession = await self.expansionEngine.expand(match: match, delimiter: delimiter)
        }
    }

    // MARK: - Placeholder navigation

    private func handlePlaceholderNavigation(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard placeholderSession != nil else { return false }
        switch Int(keyCode) {
        case kVK_Tab where !flags.contains(.maskShift):
            if let distance = placeholderSession?.advance() {
                synthesizer.moveCursorRight(distance)
                if placeholderSession?.hasNextStop != true {
                    placeholderSession = nil
                }
                return true
            }
            placeholderSession = nil
            return false
        case kVK_Escape, kVK_Return, kVK_ANSI_KeypadEnter,
             kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow:
            placeholderSession = nil
            return false
        default:
            return false
        }
    }

    // MARK: - Suggestions

    private func handleSuggestionNavigation(keyCode: Int64) -> Bool {
        guard suggestions.isVisible else { return false }
        switch Int(keyCode) {
        case kVK_DownArrow:
            suggestions.moveSelection(by: 1)
            return true
        case kVK_UpArrow:
            suggestions.moveSelection(by: -1)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            suggestions.acceptSelected()
            return true
        case kVK_Escape:
            suggestions.hide()
            return true
        default:
            return false
        }
    }

    private func refreshSuggestions() {
        guard suggestionsEnabled else { return }
        let token = buffer.trailingToken(separators: delimiters)
        let prefix = triggerPrefix
        guard !prefix.isEmpty, token.hasPrefix(prefix), token.count > prefix.count else {
            suggestions.hide()
            return
        }
        let partial = String(token.dropFirst(prefix.count))
        let matches = engine.suggestions(forPartialTrigger: partial)
        if matches.isEmpty {
            suggestions.hide()
        } else {
            suggestions.show(snippets: matches, typedLength: token.count, prefix: prefix)
        }
    }

    private func acceptSuggestion(_ snippet: Snippet, typedLength: Int) {
        buffer.reset()
        suggestions.hide()
        startExpansion(SnippetMatch(snippet: snippet, typedLength: typedLength), delimiter: nil)
    }
}
