import Foundation

/// A parsed snippet replacement template.
///
/// Templates may contain:
/// - `{{variable}}` / `{{variable:argument}}` — resolved at expansion time.
/// - `|` or `{{cursor}}` — cursor placeholders (`\|` inserts a literal pipe).
///
/// Variable names that are neither built-in nor custom become fill-in
/// prompts shown to the user before expansion.
nonisolated struct ExpansionTemplate: Sendable {
    enum Token: Equatable, Sendable {
        case literal(String)
        case variable(name: String, argument: String?)
        case cursor
    }

    let tokens: [Token]

    init(parsing template: String) {
        var tokens: [Token] = []
        var literal = ""
        var index = template.startIndex

        func flushLiteral() {
            if !literal.isEmpty {
                tokens.append(.literal(literal))
                literal = ""
            }
        }

        while index < template.endIndex {
            let character = template[index]
            if character == "\\", template.index(after: index) < template.endIndex,
               template[template.index(after: index)] == "|" {
                literal.append("|")
                index = template.index(index, offsetBy: 2)
            } else if character == "|" {
                flushLiteral()
                tokens.append(.cursor)
                index = template.index(after: index)
            } else if character == "{",
                      let close = template.range(of: "}}", range: index..<template.endIndex),
                      template[index...].hasPrefix("{{") {
                let inner = String(template[template.index(index, offsetBy: 2)..<close.lowerBound])
                if inner.lowercased() == "cursor" {
                    flushLiteral()
                    tokens.append(.cursor)
                } else if inner.isEmpty {
                    literal.append("{{}}")
                } else {
                    flushLiteral()
                    let parts = inner.split(separator: ":", maxSplits: 1).map(String.init)
                    tokens.append(.variable(
                        name: parts[0].trimmingCharacters(in: .whitespaces),
                        argument: parts.count > 1 ? parts[1] : nil
                    ))
                }
                index = close.upperBound
            } else {
                literal.append(character)
                index = template.index(after: index)
            }
        }
        flushLiteral()
        self.tokens = tokens
    }

    /// All variable names referenced by the template, in order, deduplicated.
    var variableNames: [String] {
        var seen: Set<String> = []
        var names: [String] = []
        for case let .variable(name, _) in tokens where seen.insert(name).inserted {
            names.append(name)
        }
        return names
    }

    var containsCursorPlaceholder: Bool {
        tokens.contains(.cursor)
    }

    /// Renders the template, resolving each variable through `resolve`.
    /// Unresolvable variables are emitted verbatim so the user can see what failed.
    func render(resolve: (_ name: String, _ argument: String?) -> String?) -> ResolvedExpansion {
        var text = ""
        var cursorOffsets: [Int] = []
        for token in tokens {
            switch token {
            case .literal(let value):
                text += value
            case .variable(let name, let argument):
                text += resolve(name, argument) ?? "{{\(name)}}"
            case .cursor:
                cursorOffsets.append(text.count)
            }
        }
        return ResolvedExpansion(text: text, cursorOffsets: cursorOffsets)
    }
}

/// The final text to insert plus the character offsets of any cursor stops.
nonisolated struct ResolvedExpansion: Equatable, Sendable {
    var text: String
    /// Character offsets into `text` where the cursor may be placed, ascending.
    var cursorOffsets: [Int]

    /// Arrow-key presses needed to move the cursor from the end of the
    /// inserted text back to the first placeholder.
    var initialCursorMove: Int {
        guard let first = cursorOffsets.first else { return 0 }
        return text.count - first
    }
}
