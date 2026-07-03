import Foundation

/// A fixed-capacity buffer of recently typed characters.
///
/// The keyboard monitor feeds every printable keystroke into this buffer and
/// asks for the trailing token whenever a delimiter is pressed. Old characters
/// fall off the front so memory use stays constant no matter how long the
/// user types.
nonisolated struct RollingBuffer: Sendable {
    private(set) var characters: [Character] = []
    let capacity: Int

    init(capacity: Int = 64) {
        self.capacity = max(8, capacity)
    }

    var isEmpty: Bool { characters.isEmpty }

    var contents: String { String(characters) }

    mutating func append(_ character: Character) {
        characters.append(character)
        if characters.count > capacity {
            characters.removeFirst(characters.count - capacity)
        }
    }

    mutating func append(contentsOf string: String) {
        for character in string { append(character) }
    }

    /// Mirrors the user pressing delete: drops the most recent character.
    mutating func deleteLast() {
        if !characters.isEmpty { characters.removeLast() }
    }

    mutating func reset() {
        characters.removeAll(keepingCapacity: true)
    }

    /// The trailing run of characters that are not separators — the token the
    /// user is currently typing. Whitespace always separates tokens.
    func trailingToken(separators: Set<Character>) -> String {
        var token: [Character] = []
        for character in characters.reversed() {
            if character.isWhitespace || separators.contains(character) { break }
            token.append(character)
        }
        return String(token.reversed())
    }
}
