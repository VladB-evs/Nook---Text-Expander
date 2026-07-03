import AppKit
import Carbon.HIToolbox
import Testing
@testable import Nook

/// Records posted events instead of touching the real event system.
private final class FakeSynthesizer: EventSynthesizing {
    enum Call: Equatable {
        case backspaces(Int)
        case moveLeft(Int)
        case moveRight(Int)
        case type(String)
        case paste
        case key(CGKeyCode)
    }

    var calls: [Call] = []

    func postBackspaces(_ count: Int) { calls.append(.backspaces(count)) }
    func moveCursorLeft(_ count: Int) { calls.append(.moveLeft(count)) }
    func moveCursorRight(_ count: Int) { calls.append(.moveRight(count)) }
    func typeText(_ text: String) { calls.append(.type(text)) }
    func postPasteShortcut() { calls.append(.paste) }
    func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) { calls.append(.key(keyCode)) }
}

private final class FakePasteboard: Pasteboarding {
    var storage: [[NSPasteboard.PasteboardType: Data]] = []
    var types: [NSPasteboard.PasteboardType]? { storage.first.map { Array($0.keys) } }
    func items() -> [[NSPasteboard.PasteboardType: Data]] { storage }
    func setItems(_ items: [[NSPasteboard.PasteboardType: Data]]) { storage = items }
    func setContent(_ content: PasteContent) {
        if case .plain(let text) = content { storage = [[.string: Data(text.utf8)]] }
    }
    func string() -> String {
        storage.first?[.string].map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
}

struct ExpansionEngineTests {
    private let spaceDelimiter = DelimiterKey(keyCode: Int64(kVK_Space), flagsRawValue: 0)

    private func makeEngine(
        settings: AppSettings = AppSettings(),
        fillIns: [String: String]? = nil
    ) -> (ExpansionEngine, FakeSynthesizer, FakePasteboard) {
        let synthesizer = FakeSynthesizer()
        let pasteboard = FakePasteboard()
        let engine = ExpansionEngine(
            synthesizer: synthesizer,
            clipboard: ClipboardManager(pasteboard: pasteboard),
            resolver: VariableResolver(),
            scripts: ScriptEngine(),
            logger: DebugLogger(),
            currentSettings: { settings }
        )
        engine.fillInProvider = { names, _ in
            fillIns.map { values in
                Dictionary(uniqueKeysWithValues: names.map { ($0, values[$0] ?? "") })
            }
        }
        return (engine, synthesizer, pasteboard)
    }

    @Test func typesShortTextAndResendsDelimiter() async {
        let (engine, synthesizer, _) = makeEngine()
        let snippet = Snippet(trigger: "src", replacement: "../../components/Button")
        let session = await engine.expand(
            match: SnippetMatch(snippet: snippet, typedLength: 4),
            delimiter: spaceDelimiter
        )
        #expect(session == nil)
        #expect(synthesizer.calls == [
            .backspaces(4),
            .type("../../components/Button"),
            .key(CGKeyCode(kVK_Space)),
        ])
    }

    @Test func longTextGoesThroughClipboard() async {
        var settings = AppSettings()
        settings.typingLengthThreshold = 10
        let (engine, synthesizer, pasteboard) = makeEngine(settings: settings)
        let snippet = Snippet(trigger: "long", replacement: String(repeating: "x", count: 50))
        _ = await engine.expand(
            match: SnippetMatch(snippet: snippet, typedLength: 5),
            delimiter: spaceDelimiter
        )
        #expect(synthesizer.calls == [
            .backspaces(5),
            .paste,
            .key(CGKeyCode(kVK_Space)),
        ])
        #expect(pasteboard.string() == String(repeating: "x", count: 50))
    }

    @Test func snippetMethodPreferenceOverridesDefault() async {
        let (engine, synthesizer, _) = makeEngine()
        var snippet = Snippet(trigger: "p", replacement: "tiny")
        snippet.expansionMethod = .clipboard
        _ = await engine.expand(match: SnippetMatch(snippet: snippet, typedLength: 2), delimiter: nil)
        #expect(synthesizer.calls.contains(.paste))
        #expect(!synthesizer.calls.contains(.type("tiny")))
    }

    @Test func cursorPlaceholderMovesCursorAndConsumesDelimiter() async {
        let (engine, synthesizer, _) = makeEngine()
        let snippet = Snippet(trigger: "log", replacement: "console.log(|)")
        let session = await engine.expand(
            match: SnippetMatch(snippet: snippet, typedLength: 4),
            delimiter: spaceDelimiter
        )
        #expect(session == nil) // single placeholder → no tab session
        #expect(synthesizer.calls == [
            .backspaces(4),
            .type("console.log()"),
            .moveLeft(1),
        ])
    }

    @Test func multiplePlaceholdersCreateSession() async {
        let (engine, _, _) = makeEngine()
        let snippet = Snippet(trigger: "a", replacement: "<a href=\"|\">|</a>")
        let session = await engine.expand(
            match: SnippetMatch(snippet: snippet, typedLength: 2),
            delimiter: spaceDelimiter
        )
        #expect(session != nil)
    }

    @Test func fillInValuesAreInterpolated() async {
        let (engine, synthesizer, _) = makeEngine(fillIns: ["client": "Acme"])
        let snippet = Snippet(trigger: "m", replacement: "Meeting with {{client}}")
        _ = await engine.expand(match: SnippetMatch(snippet: snippet, typedLength: 2), delimiter: nil)
        #expect(synthesizer.calls == [.backspaces(2), .type("Meeting with Acme")])
    }

    @Test func cancelledFillInLeavesTypedTextAlone() async {
        let (engine, synthesizer, _) = makeEngine(fillIns: nil)
        let snippet = Snippet(trigger: "m", replacement: "Meeting with {{client}}")
        _ = await engine.expand(
            match: SnippetMatch(snippet: snippet, typedLength: 2),
            delimiter: spaceDelimiter
        )
        // No backspaces, no insertion — only the delimiter is re-sent.
        #expect(synthesizer.calls == [.key(CGKeyCode(kVK_Space))])
    }

    @Test func scriptSnippetInsertsScriptResult() async {
        let (engine, synthesizer, _) = makeEngine()
        let snippet = Snippet(trigger: "two", replacement: "return 1 + 1;", kind: .script)
        _ = await engine.expand(match: SnippetMatch(snippet: snippet, typedLength: 4), delimiter: nil)
        #expect(synthesizer.calls == [.backspaces(4), .type("2")])
    }

    @Test func failingScriptDoesNotDeleteTypedText() async {
        let (engine, synthesizer, _) = makeEngine()
        let snippet = Snippet(trigger: "bad", replacement: "throw new Error('nope');", kind: .script)
        _ = await engine.expand(
            match: SnippetMatch(snippet: snippet, typedLength: 4),
            delimiter: spaceDelimiter
        )
        #expect(synthesizer.calls == [.key(CGKeyCode(kVK_Space))])
    }

    @Test func imageSnippetPastes() async {
        let (engine, synthesizer, _) = makeEngine()
        var snippet = Snippet(trigger: "img", kind: .image)
        snippet.imageData = Data([0x89, 0x50, 0x4E, 0x47])
        _ = await engine.expand(match: SnippetMatch(snippet: snippet, typedLength: 4), delimiter: nil)
        #expect(synthesizer.calls == [.backspaces(4), .paste])
    }
}
