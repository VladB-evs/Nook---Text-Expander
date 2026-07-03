import Foundation

/// Resolves `{{variable}}` references at expansion time.
///
/// Sources, in priority order: built-in dynamic variables, then user-defined
/// custom variables. Environment lookups (clipboard contents, selected text,
/// current date) are injected as closures so the resolver stays pure and
/// testable. Names that resolve to nil are treated as fill-in prompts.
@MainActor
final class VariableResolver {
    static let builtInNames: [String] = [
        "date", "time", "datetime", "year", "month", "day", "weekday",
        "uuid", "hostname", "username", "clipboard", "selection", "random", "unix",
    ]

    private(set) var customVariables: [String: CustomVariable] = [:]

    var now: () -> Date
    var clipboardText: () -> String
    var selectedText: () -> String
    /// Executes a script variable's source; nil on failure.
    var runScript: (@MainActor (String) -> String?)?

    init(
        now: @escaping () -> Date = { .now },
        clipboardText: @escaping () -> String = { "" },
        selectedText: @escaping () -> String = { "" }
    ) {
        self.now = now
        self.clipboardText = clipboardText
        self.selectedText = selectedText
    }

    func updateCustomVariables(_ variables: [CustomVariable]) {
        customVariables = Dictionary(
            variables.map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Returns nil when the name is unknown — the caller then prompts the user.
    func resolve(name: String, argument: String? = nil) -> String? {
        let date = now()
        switch name.lowercased() {
        case "date": return format(date, argument ?? "yyyy-MM-dd")
        case "time": return format(date, argument ?? "HH:mm")
        case "datetime": return format(date, argument ?? "yyyy-MM-dd HH:mm")
        case "year": return format(date, "yyyy")
        case "month": return format(date, "MM")
        case "day": return format(date, "dd")
        case "weekday": return format(date, "EEEE")
        case "uuid": return UUID().uuidString
        case "hostname": return ProcessInfo.processInfo.hostName
        case "username": return NSUserName()
        case "clipboard": return clipboardText()
        case "selection": return selectedText()
        case "random": return String(Int.random(in: 0...999_999))
        case "unix": return String(Int(date.timeIntervalSince1970))
        default:
            guard let variable = customVariables[name.lowercased()] else { return nil }
            switch variable.kind {
            case .text: return variable.value
            case .script: return runScript?(variable.value) ?? ""
            }
        }
    }

    /// Variables in the template that need to be asked from the user.
    func fillInNames(in template: ExpansionTemplate) -> [String] {
        template.variableNames.filter { name in
            !Self.builtInNames.contains(name.lowercased()) && customVariables[name.lowercased()] == nil
        }
    }

    private func format(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
