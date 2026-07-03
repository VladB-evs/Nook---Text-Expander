import AppKit
import SwiftUI

/// A borderless-friendly panel that can take keyboard focus without
/// activating Nook, so the target app keeps its frontmost status while the
/// user fills in snippet values.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Prompts the user for fill-in variable values before an expansion.
@MainActor
final class FillInPresenter {
    private var panel: NSPanel?
    private var continuation: CheckedContinuation<[String: String]?, Never>?

    /// Presents the form and suspends until the user submits or cancels.
    func requestValues(names: [String], snippetName: String) async -> [String: String]? {
        finish(with: nil)
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            present(names: names, snippetName: snippetName)
        }
    }

    private func present(names: [String], snippetName: String) {
        let view = FillInFormView(
            snippetName: snippetName,
            names: names,
            onSubmit: { [weak self] values in self?.finish(with: values) },
            onCancel: { [weak self] in self?.finish(with: nil) }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Nook"
        panel.level = .floating
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false
        panel.center()
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func finish(with values: [String: String]?) {
        panel?.orderOut(nil)
        panel = nil
        continuation?.resume(returning: values)
        continuation = nil
    }
}

private struct FillInFormView: View {
    let snippetName: String
    let names: [String]
    let onSubmit: ([String: String]) -> Void
    let onCancel: () -> Void

    @State private var values: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(snippetName.isEmpty ? "Fill In" : snippetName)
                .font(.headline)
            ForEach(names, id: \.self) { name in
                TextField(name, text: binding(for: name))
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Insert") { onSubmit(values) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func binding(for name: String) -> Binding<String> {
        Binding(
            get: { values[name] ?? "" },
            set: { values[name] = $0 }
        )
    }
}
