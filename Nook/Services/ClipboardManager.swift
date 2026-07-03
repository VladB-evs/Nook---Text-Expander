import AppKit

/// Content that can be delivered through the pasteboard.
nonisolated enum PasteContent: Sendable {
    case plain(String)
    case rich(rtf: Data, fallback: String)
    case image(Data)
}

/// Abstraction over NSPasteboard so restoration logic is unit-testable.
@MainActor
protocol Pasteboarding: AnyObject {
    var types: [NSPasteboard.PasteboardType]? { get }
    func items() -> [[NSPasteboard.PasteboardType: Data]]
    func setItems(_ items: [[NSPasteboard.PasteboardType: Data]])
    func setContent(_ content: PasteContent)
    func string() -> String
}

/// The real general pasteboard (or any named pasteboard, for tests).
@MainActor
final class SystemPasteboard: Pasteboarding {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var types: [NSPasteboard.PasteboardType]? { pasteboard.types }

    func items() -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var copy: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                copy[type] = item.data(forType: type)
            }
            return copy
        }
    }

    func setItems(_ items: [[NSPasteboard.PasteboardType: Data]]) {
        pasteboard.clearContents()
        let restored = items.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restored.isEmpty {
            pasteboard.writeObjects(restored)
        }
    }

    func setContent(_ content: PasteContent) {
        pasteboard.clearContents()
        switch content {
        case .plain(let text):
            pasteboard.setString(text, forType: .string)
        case .rich(let rtf, let fallback):
            pasteboard.setData(rtf, forType: .rtf)
            pasteboard.setString(fallback, forType: .string)
        case .image(let data):
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.setData(data, forType: .png)
            }
        }
    }

    func string() -> String {
        pasteboard.string(forType: .string) ?? ""
    }
}

/// Saves, replaces, and restores the user's clipboard around paste expansions.
///
/// The snapshot is taken immediately before the paste and restored after a
/// short delay (long enough for the target app to have read the pasteboard).
/// Back-to-back expansions reuse the original snapshot so the user's
/// clipboard survives rapid sequences.
@MainActor
final class ClipboardManager {
    private let pasteboard: any Pasteboarding
    private let logger: DebugLogger?
    private var savedItems: [[NSPasteboard.PasteboardType: Data]]?
    private var restoreTask: Task<Void, Never>?

    init(pasteboard: (any Pasteboarding)? = nil, logger: DebugLogger? = nil) {
        self.pasteboard = pasteboard ?? SystemPasteboard()
        self.logger = logger
    }

    var currentText: String { pasteboard.string() }

    /// Puts `content` on the pasteboard, remembering the previous contents.
    /// If a restore is already pending, the older snapshot is kept.
    func stage(_ content: PasteContent) {
        restoreTask?.cancel()
        if savedItems == nil {
            savedItems = pasteboard.items()
        }
        pasteboard.setContent(content)
        logger?.log(.clipboard, "Clipboard replaced for expansion")
    }

    /// Restores the snapshot after `delay`, once the target app has pasted.
    func scheduleRestore(after delay: Duration) {
        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.restoreNow()
        }
    }

    func restoreNow() {
        restoreTask?.cancel()
        guard let items = savedItems else { return }
        pasteboard.setItems(items)
        savedItems = nil
        logger?.log(.clipboard, "Clipboard restored")
    }
}
