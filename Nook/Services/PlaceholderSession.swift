import Foundation

/// Tracks Tab navigation between cursor placeholders after an expansion.
///
/// The cursor starts at the first placeholder. Because the user only ever
/// types at the current cursor position, the distance between consecutive
/// stops is invariant under those edits — advancing is always a fixed number
/// of right-arrow presses. The session ends when the stops run out or the
/// user moves the cursor by other means (arrows, clicks, Escape, app switch).
nonisolated struct PlaceholderSession: Sendable {
    private let stops: [Int]
    private var currentIndex = 0

    /// Creates a session for an expansion with at least two placeholders.
    /// Returns nil when there is nothing to navigate between.
    init?(cursorOffsets: [Int]) {
        guard cursorOffsets.count > 1 else { return nil }
        self.stops = cursorOffsets
    }

    var hasNextStop: Bool { currentIndex + 1 < stops.count }

    /// Consumes a Tab press: returns how many characters to move right to
    /// reach the next placeholder, or nil when the session is exhausted.
    mutating func advance() -> Int? {
        guard hasNextStop else { return nil }
        let distance = stops[currentIndex + 1] - stops[currentIndex]
        currentIndex += 1
        return distance
    }
}
