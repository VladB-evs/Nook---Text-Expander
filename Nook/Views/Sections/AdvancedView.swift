import SwiftUI

/// Expansion tuning and the optional debug console.
struct AdvancedView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        @Bindable var settingsStore = dependencies.settingsStore
        @Bindable var logger = dependencies.logger

        Form {
            Section("Expansion") {
                Picker("Default method", selection: $settingsStore.settings.defaultExpansionMethod) {
                    ForEach(ExpansionMethodPreference.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                if settingsStore.settings.defaultExpansionMethod == .automatic {
                    NumberSettingRow(
                        label: "Typing threshold",
                        unit: "characters",
                        value: $settingsStore.settings.typingLengthThreshold
                    )
                    Text("Replacements up to this many characters are typed; longer ones are pasted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                NumberSettingRow(
                    label: "Clipboard restore delay",
                    unit: "ms",
                    value: $settingsStore.settings.clipboardRestoreDelayMilliseconds
                )
                NumberSettingRow(
                    label: "Input buffer size",
                    unit: "characters",
                    value: $settingsStore.settings.rollingBufferCapacity
                )
            }

            Section {
                Toggle("Enable debug logging", isOn: Binding(
                    get: { settingsStore.settings.debugLoggingEnabled },
                    set: { settingsStore.settings.debugLoggingEnabled = $0 }
                ))
                if logger.isEnabled {
                    DebugConsoleView()
                }
            } header: {
                Text("Debug Console")
            } footer: {
                Text("Shows detected triggers, expansion timings, and clipboard operations. Nook never logs the content you type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.nookBackground)
        .navigationTitle("Advanced")
    }
}

/// A labeled numeric field with a unit suffix that never wraps.
private struct NumberSettingRow: View {
    let label: String
    let unit: String
    @Binding var value: Int

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField("", value: $value, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                Text(unit)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
    }
}

private struct DebugConsoleView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(dependencies.logger.entries.reversed()) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entry.date, format: .dateTime.hour().minute().second())
                                .foregroundStyle(.tertiary)
                            Text(entry.category.rawValue)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text(entry.message)
                            if let duration = entry.durationMilliseconds {
                                Text("\(duration, format: .number.precision(.fractionLength(1))) ms")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.system(.caption, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)

            Button("Clear") {
                dependencies.logger.clear()
            }
        }
    }
}
