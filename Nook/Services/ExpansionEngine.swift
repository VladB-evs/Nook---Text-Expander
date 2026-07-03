import AppKit
import Carbon.HIToolbox

/// The delimiter keystroke that completed a trigger, kept so it can be
/// re-sent after the replacement is inserted.
nonisolated struct DelimiterKey: Sendable {
    let keyCode: Int64
    let flagsRawValue: UInt64
}

/// Performs a single expansion: resolves the snippet's content, removes the
/// typed trigger, inserts the replacement, then re-sends the delimiter.
///
/// Insertion strategy:
/// - Plain text at or under the length threshold is typed as synthetic
///   keystrokes (works everywhere, including paste-hostile apps).
/// - Long text, rich text, and images go through the pasteboard: snapshot,
///   replace, Cmd+V, restore.
@MainActor
final class ExpansionEngine {
    private let synthesizer: any EventSynthesizing
    private let clipboard: ClipboardManager
    private let resolver: VariableResolver
    private let scripts: ScriptEngine
    private let logger: DebugLogger
    private let currentSettings: @MainActor () -> AppSettings

    /// Asks the user for fill-in values. Returns nil when cancelled.
    var fillInProvider: (@MainActor (_ names: [String], _ snippetName: String) async -> [String: String]?)?

    init(
        synthesizer: any EventSynthesizing,
        clipboard: ClipboardManager,
        resolver: VariableResolver,
        scripts: ScriptEngine,
        logger: DebugLogger,
        currentSettings: @escaping @MainActor () -> AppSettings
    ) {
        self.synthesizer = synthesizer
        self.clipboard = clipboard
        self.resolver = resolver
        self.scripts = scripts
        self.logger = logger
        self.currentSettings = currentSettings
    }

    /// Expands `match`, returning a placeholder session when the snippet has
    /// multiple cursor stops to Tab between.
    func expand(match: SnippetMatch, delimiter: DelimiterKey?) async -> PlaceholderSession? {
        let snippet = match.snippet
        let start = CFAbsoluteTimeGetCurrent()
        logger.log(.trigger, "Matched \"\(snippet.trigger)\" (\(snippet.name))")

        var text: String?
        var cursorOffsets: [Int] = []
        var pasteContent: PasteContent?

        switch snippet.kind {
        case .text:
            let template = ExpansionTemplate(parsing: snippet.replacement)
            let fillIns = resolver.fillInNames(in: template)
            var fillValues: [String: String] = [:]
            if !fillIns.isEmpty {
                guard let values = await fillInProvider?(fillIns, snippet.name) else {
                    resend(delimiter)
                    logger.log(.expansion, "Fill-in cancelled for \"\(snippet.trigger)\"")
                    return nil
                }
                fillValues = values
            }
            let resolved = template.render { name, argument in
                fillValues[name] ?? resolver.resolve(name: name, argument: argument)
            }
            text = resolved.text
            cursorOffsets = resolved.cursorOffsets

        case .script:
            do {
                text = try scripts.run(snippet.replacement, language: snippet.scriptLanguage)
            } catch {
                resend(delimiter)
                logger.log(.error, "Script \"\(snippet.trigger)\": \(error.localizedDescription)")
                return nil
            }

        case .richText:
            if let rtf = snippet.rtfData {
                pasteContent = .rich(rtf: rtf, fallback: snippet.replacement)
            } else {
                text = snippet.replacement
            }

        case .image:
            guard let data = snippet.imageData else {
                resend(delimiter)
                logger.log(.error, "Image snippet \"\(snippet.trigger)\" has no image")
                return nil
            }
            pasteContent = .image(data)
        }

        let settings = currentSettings()
        synthesizer.postBackspaces(match.typedLength)

        if let pasteContent {
            insertViaClipboard(pasteContent, settings: settings)
        } else if let text {
            switch method(for: snippet, textLength: text.count, settings: settings) {
            case .typing:
                synthesizer.typeText(text)
            case .clipboard:
                insertViaClipboard(.plain(text), settings: settings)
            }
        }

        var session: PlaceholderSession?
        if let text, let firstStop = cursorOffsets.first {
            synthesizer.moveCursorLeft(text.count - firstStop)
            session = PlaceholderSession(cursorOffsets: cursorOffsets)
        } else {
            // Snippets with cursor placeholders consume the delimiter; the
            // cursor is mid-snippet, where the delimiter would not belong.
            resend(delimiter)
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.log(.expansion, "Expanded \"\(snippet.trigger)\"", durationMilliseconds: elapsed)
        return session
    }

    private enum InsertionMethod {
        case typing
        case clipboard
    }

    private func method(for snippet: Snippet, textLength: Int, settings: AppSettings) -> InsertionMethod {
        let preference = snippet.expansionMethod == .automatic
            ? settings.defaultExpansionMethod
            : snippet.expansionMethod
        switch preference {
        case .typing: return .typing
        case .clipboard: return .clipboard
        case .automatic: return textLength <= settings.typingLengthThreshold ? .typing : .clipboard
        }
    }

    private func insertViaClipboard(_ content: PasteContent, settings: AppSettings) {
        clipboard.stage(content)
        synthesizer.postPasteShortcut()
        clipboard.scheduleRestore(after: .milliseconds(settings.clipboardRestoreDelayMilliseconds))
    }

    private func resend(_ delimiter: DelimiterKey?) {
        guard let delimiter else { return }
        synthesizer.postKey(CGKeyCode(delimiter.keyCode), flags: CGEventFlags(rawValue: delimiter.flagsRawValue))
    }
}
