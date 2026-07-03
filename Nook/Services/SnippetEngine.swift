import Foundation

/// A successful trigger match.
nonisolated struct SnippetMatch: Sendable {
    let snippet: Snippet
    /// Number of characters the user typed for this match (prefix + trigger),
    /// i.e. how many backspaces are needed to remove it.
    let typedLength: Int
}

/// O(1) trigger lookup over the enabled snippets.
///
/// The engine keeps two hash maps — one for case-sensitive triggers keyed
/// verbatim, one for case-insensitive triggers keyed lowercased — plus a
/// sorted trigger list used for prefix queries by the suggestion popover.
/// Triggers are stored *without* the global prefix; the prefix is stripped
/// from the typed token at match time, so changing the prefix in settings
/// instantly affects every snippet.
nonisolated final class SnippetEngine: @unchecked Sendable {
    private var caseSensitive: [String: Snippet] = [:]
    private var caseInsensitive: [String: Snippet] = [:]
    private var sortedTriggers: [String] = []
    private(set) var triggerPrefix: String = ";"

    /// Rebuilds the lookup tables. Call whenever snippets or the prefix change.
    func rebuild(snippets: [Snippet], triggerPrefix: String) {
        self.triggerPrefix = triggerPrefix
        caseSensitive.removeAll()
        caseInsensitive.removeAll()
        var triggers: Set<String> = []
        for snippet in snippets where snippet.isEnabled && !snippet.trigger.isEmpty {
            if snippet.isCaseSensitive {
                caseSensitive[snippet.trigger] = snippet
            } else {
                caseInsensitive[snippet.trigger.lowercased()] = snippet
            }
            triggers.insert(snippet.trigger.lowercased())
        }
        sortedTriggers = triggers.sorted()
    }

    /// Looks up a fully typed token (still carrying the prefix), returning a
    /// match if some enabled snippet's prefixed trigger equals the token — or,
    /// for snippets that allow mid-word expansion, ends it.
    func match(token: String) -> SnippetMatch? {
        guard !token.isEmpty else { return nil }

        if token.hasPrefix(triggerPrefix) {
            let candidate = String(token.dropFirst(triggerPrefix.count))
            if let snippet = lookup(candidate) {
                return SnippetMatch(snippet: snippet, typedLength: triggerPrefix.count + candidate.count)
            }
        }

        // Mid-word match: the prefix appears later in the token, e.g. "foo;src".
        if !triggerPrefix.isEmpty,
           let range = token.range(of: triggerPrefix, options: .backwards),
           range.lowerBound != token.startIndex {
            let candidate = String(token[range.upperBound...])
            if let snippet = lookup(candidate), !snippet.wholeWordOnly {
                return SnippetMatch(snippet: snippet, typedLength: triggerPrefix.count + candidate.count)
            }
        }
        return nil
    }

    /// Snippets whose trigger starts with the partially typed trigger
    /// (token without prefix). Used by the suggestion popover.
    func suggestions(forPartialTrigger partial: String, limit: Int = 6) -> [Snippet] {
        guard !partial.isEmpty else { return [] }
        let needle = partial.lowercased()
        var results: [Snippet] = []
        for trigger in sortedTriggers[lowerBound(of: needle)...] {
            guard trigger.hasPrefix(needle) else { break }
            if let snippet = caseInsensitive[trigger] ?? caseSensitiveSnippet(forLowercased: trigger) {
                results.append(snippet)
                if results.count == limit { break }
            }
        }
        return results
    }

    private func lookup(_ candidate: String) -> Snippet? {
        guard !candidate.isEmpty else { return nil }
        return caseSensitive[candidate] ?? caseInsensitive[candidate.lowercased()]
    }

    private func caseSensitiveSnippet(forLowercased trigger: String) -> Snippet? {
        // Rare path: suggestion listing for case-sensitive snippets.
        caseSensitive.first { $0.key.lowercased() == trigger }?.value
    }

    /// Binary search for the first sorted trigger >= needle.
    private func lowerBound(of needle: String) -> Int {
        var low = 0
        var high = sortedTriggers.count
        while low < high {
            let mid = (low + high) / 2
            if sortedTriggers[mid] < needle { low = mid + 1 } else { high = mid }
        }
        return low
    }
}
