import AppKit
import SwiftUI

/// Shows a small non-activating panel listing snippets whose triggers start
/// with what the user has typed so far. Keyboard navigation is driven by the
/// coordinator (the panel never takes focus away from the target app).
@MainActor
@Observable
final class SuggestionController {
    private(set) var snippets: [Snippet] = []
    private(set) var selectedIndex = 0
    private(set) var triggerPrefix = ";"

    /// Called when the user accepts a suggestion (snippet, characters typed so far).
    @ObservationIgnored var onAccept: (@MainActor (Snippet, Int) -> Void)?

    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var typedLength = 0

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(snippets: [Snippet], typedLength: Int, prefix: String) {
        self.snippets = snippets
        self.typedLength = typedLength
        self.triggerPrefix = prefix
        if selectedIndex >= snippets.count {
            selectedIndex = 0
        }
        let panel = ensurePanel()
        position(panel)
        if !panel.isVisible {
            selectedIndex = 0
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel?.orderOut(nil)
        snippets = []
        selectedIndex = 0
    }

    func moveSelection(by delta: Int) {
        guard !snippets.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + snippets.count) % snippets.count
    }

    func acceptSelected() {
        guard snippets.indices.contains(selectedIndex) else { return }
        let snippet = snippets[selectedIndex]
        let length = typedLength
        hide()
        onAccept?(snippet, length)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = NSHostingView(rootView: SuggestionListView(controller: self))
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        panel.setContentSize(NSSize(width: 240, height: CGFloat(snippets.count) * 30 + 12))
        let anchor: NSPoint
        if let caret = AccessibilityReader.caretRect() {
            anchor = NSPoint(x: caret.minX, y: caret.minY - 4)
        } else {
            let mouse = NSEvent.mouseLocation
            anchor = NSPoint(x: mouse.x, y: mouse.y - 20)
        }
        panel.setFrameTopLeftPoint(anchor)
    }
}

/// The popover's row list. Pure rendering; selection state lives in the controller.
private struct SuggestionListView: View {
    let controller: SuggestionController

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(controller.snippets.enumerated()), id: \.element.id) { index, snippet in
                HStack(spacing: 8) {
                    Text(controller.triggerPrefix + snippet.trigger)
                        .font(.system(.body, design: .monospaced))
                    Spacer(minLength: 4)
                    Text(snippet.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    index == controller.selectedIndex
                        ? AnyShapeStyle(Color.accentColor.opacity(0.25))
                        : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 5)
                )
            }
        }
        .padding(6)
        .frame(width: 240, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
