import AppKit
import Testing
@testable import Nook

/// In-memory pasteboard so restoration logic runs without touching the
/// real system clipboard.
private final class FakePasteboard: Pasteboarding {
    var storage: [[NSPasteboard.PasteboardType: Data]] = []

    var types: [NSPasteboard.PasteboardType]? {
        storage.first.map { Array($0.keys) }
    }

    func items() -> [[NSPasteboard.PasteboardType: Data]] { storage }

    func setItems(_ items: [[NSPasteboard.PasteboardType: Data]]) {
        storage = items
    }

    func setContent(_ content: PasteContent) {
        switch content {
        case .plain(let text):
            storage = [[.string: Data(text.utf8)]]
        case .rich(let rtf, let fallback):
            storage = [[.rtf: rtf, .string: Data(fallback.utf8)]]
        case .image(let data):
            storage = [[.png: data]]
        }
    }

    func string() -> String {
        guard let data = storage.first?[.string] else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

struct ClipboardManagerTests {
    @Test func stageReplacesAndRestoreBringsBackOriginal() {
        let pasteboard = FakePasteboard()
        pasteboard.setContent(.plain("user's precious clipboard"))
        let manager = ClipboardManager(pasteboard: pasteboard)

        manager.stage(.plain("expansion text"))
        #expect(pasteboard.string() == "expansion text")

        manager.restoreNow()
        #expect(pasteboard.string() == "user's precious clipboard")
    }

    @Test func backToBackStagesKeepOriginalSnapshot() {
        let pasteboard = FakePasteboard()
        pasteboard.setContent(.plain("original"))
        let manager = ClipboardManager(pasteboard: pasteboard)

        manager.stage(.plain("first expansion"))
        manager.stage(.plain("second expansion"))
        manager.restoreNow()
        #expect(pasteboard.string() == "original")
    }

    @Test func restoreWithoutStageIsHarmless() {
        let pasteboard = FakePasteboard()
        pasteboard.setContent(.plain("untouched"))
        let manager = ClipboardManager(pasteboard: pasteboard)
        manager.restoreNow()
        #expect(pasteboard.string() == "untouched")
    }

    @Test func scheduledRestoreFires() async throws {
        let pasteboard = FakePasteboard()
        pasteboard.setContent(.plain("original"))
        let manager = ClipboardManager(pasteboard: pasteboard)

        manager.stage(.plain("expansion"))
        manager.scheduleRestore(after: .milliseconds(10))
        try await Task.sleep(for: .milliseconds(200))
        #expect(pasteboard.string() == "original")
    }

    @Test func richContentIncludesPlainFallback() {
        let pasteboard = FakePasteboard()
        let manager = ClipboardManager(pasteboard: pasteboard)
        manager.stage(.rich(rtf: Data([0x01]), fallback: "fallback"))
        #expect(pasteboard.string() == "fallback")
        #expect(pasteboard.storage.first?[.rtf] == Data([0x01]))
    }
}
