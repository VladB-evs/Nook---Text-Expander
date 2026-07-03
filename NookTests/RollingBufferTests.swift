import Testing
@testable import Nook

struct RollingBufferTests {
    @Test func appendsAndReturnsContents() {
        var buffer = RollingBuffer(capacity: 16)
        buffer.append(contentsOf: "hello")
        #expect(buffer.contents == "hello")
    }

    @Test func capacityDropsOldestCharacters() {
        var buffer = RollingBuffer(capacity: 8)
        buffer.append(contentsOf: "abcdefghij")
        #expect(buffer.contents == "cdefghij")
    }

    @Test func deleteLastMirrorsBackspace() {
        var buffer = RollingBuffer(capacity: 16)
        buffer.append(contentsOf: ";srcc")
        buffer.deleteLast()
        #expect(buffer.contents == ";src")
        buffer.reset()
        buffer.deleteLast()
        #expect(buffer.isEmpty)
    }

    @Test func trailingTokenStopsAtWhitespace() {
        var buffer = RollingBuffer(capacity: 32)
        buffer.append(contentsOf: "hello ;src")
        #expect(buffer.trailingToken(separators: []) == ";src")
    }

    @Test func trailingTokenStopsAtSeparators() {
        var buffer = RollingBuffer(capacity: 32)
        buffer.append(contentsOf: "a,b.;src")
        #expect(buffer.trailingToken(separators: [",", "."]) == ";src")
    }

    @Test func trailingTokenDoesNotBreakOnPrefixCharacter() {
        // The prefix character (";") is excluded from separators by settings,
        // so the token keeps it even though ";" is a default delimiter.
        var buffer = RollingBuffer(capacity: 32)
        buffer.append(contentsOf: "note: ;email")
        #expect(buffer.trailingToken(separators: [":", ".", ","]) == ";email")
    }

    @Test func resetClearsEverything() {
        var buffer = RollingBuffer(capacity: 16)
        buffer.append(contentsOf: "something")
        buffer.reset()
        #expect(buffer.isEmpty)
        #expect(buffer.trailingToken(separators: []) == "")
    }
}
