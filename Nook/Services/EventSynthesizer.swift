import AppKit
import Carbon.HIToolbox

/// The key-event output surface, abstracted so the expansion pipeline can be
/// exercised in tests without posting real system events.
@MainActor
protocol EventSynthesizing: AnyObject {
    func postBackspaces(_ count: Int)
    func moveCursorLeft(_ count: Int)
    func moveCursorRight(_ count: Int)
    func typeText(_ text: String)
    func postPasteShortcut()
    func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags)
}

/// Posts synthetic keyboard events (backspaces, typed text, shortcuts).
///
/// Every event is tagged with a marker in its user-data field so the
/// keyboard monitor can tell Nook's own events apart from real keystrokes
/// and never re-processes them.
@MainActor
final class EventSynthesizer: EventSynthesizing {
    /// "Nook" in ASCII — stamped on every synthetic event.
    static let syntheticMarker: Int64 = 0x4E6F6F6B

    private let source = CGEventSource(stateID: .combinedSessionState)

    static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == syntheticMarker
    }

    func postBackspaces(_ count: Int) {
        for _ in 0..<count {
            postKey(CGKeyCode(kVK_Delete))
        }
    }

    func postArrows(_ keyCode: Int, count: Int) {
        for _ in 0..<count {
            postKey(CGKeyCode(keyCode))
        }
    }

    func moveCursorLeft(_ count: Int) {
        postArrows(kVK_LeftArrow, count: count)
    }

    func moveCursorRight(_ count: Int) {
        postArrows(kVK_RightArrow, count: count)
    }

    /// Types arbitrary Unicode text by attaching string payloads to key events.
    /// Chunked because a single event carries at most 20 UTF-16 units reliably.
    func typeText(_ text: String) {
        let units = Array(text.replacingOccurrences(of: "\n", with: "\r").utf16)
        var index = 0
        while index < units.count {
            let chunk = Array(units[index..<min(index + 16, units.count)])
            postUnicodeChunk(chunk)
            index += chunk.count
        }
    }

    func postPasteShortcut() {
        postKey(CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
    }

    /// Re-sends a swallowed delimiter with its original key code and modifiers.
    func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        mark(down)
        mark(up)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func postUnicodeChunk(_ units: [UniChar]) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }
        units.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        mark(down)
        mark(up)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func mark(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
    }
}
