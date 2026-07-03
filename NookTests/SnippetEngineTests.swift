import Testing
@testable import Nook

struct SnippetEngineTests {
    private func makeEngine(prefix: String = ";", _ snippets: [Snippet]) -> SnippetEngine {
        let engine = SnippetEngine()
        engine.rebuild(snippets: snippets, triggerPrefix: prefix)
        return engine
    }

    @Test func matchesExactPrefixedToken() {
        let engine = makeEngine([Snippet(trigger: "src", replacement: "../../components/Button")])
        let match = engine.match(token: ";src")
        #expect(match?.snippet.trigger == "src")
        #expect(match?.typedLength == 4)
    }

    @Test func doesNotMatchWithoutPrefix() {
        let engine = makeEngine([Snippet(trigger: "src")])
        #expect(engine.match(token: "src") == nil)
    }

    @Test func caseInsensitiveByDefault() {
        let engine = makeEngine([Snippet(trigger: "Sig")])
        #expect(engine.match(token: ";sig") != nil)
        #expect(engine.match(token: ";SIG") != nil)
    }

    @Test func caseSensitiveWhenRequested() {
        let engine = makeEngine([Snippet(trigger: "Sig", isCaseSensitive: true)])
        #expect(engine.match(token: ";Sig") != nil)
        #expect(engine.match(token: ";sig") == nil)
    }

    @Test func disabledSnippetsNeverMatch() {
        let engine = makeEngine([Snippet(trigger: "src", isEnabled: false)])
        #expect(engine.match(token: ";src") == nil)
    }

    @Test func prefixChangeAffectsAllSnippets() {
        let engine = makeEngine(prefix: "//", [Snippet(trigger: "src")])
        #expect(engine.match(token: "//src") != nil)
        #expect(engine.match(token: ";src") == nil)
    }

    @Test func multiCharacterPrefixTypedLength() {
        let engine = makeEngine(prefix: "::", [Snippet(trigger: "addr")])
        #expect(engine.match(token: "::addr")?.typedLength == 6)
    }

    @Test func wholeWordOnlyRejectsMidWordMatch() {
        let engine = makeEngine([Snippet(trigger: "src", wholeWordOnly: true)])
        #expect(engine.match(token: "foo;src") == nil)
    }

    @Test func midWordMatchWhenWholeWordDisabled() {
        let engine = makeEngine([Snippet(trigger: "src", wholeWordOnly: false)])
        let match = engine.match(token: "foo;src")
        #expect(match?.snippet.trigger == "src")
        #expect(match?.typedLength == 4)
    }

    @Test func suggestionsReturnPrefixMatchesOnly() {
        let engine = makeEngine([
            Snippet(trigger: "src"),
            Snippet(trigger: "script"),
            Snippet(trigger: "srv"),
            Snippet(trigger: "email"),
        ])
        let triggers = engine.suggestions(forPartialTrigger: "sr").map(\.trigger).sorted()
        #expect(triggers == ["src", "srv"])
        let all = engine.suggestions(forPartialTrigger: "s").map(\.trigger).sorted()
        #expect(all == ["script", "src", "srv"])
        #expect(engine.suggestions(forPartialTrigger: "x").isEmpty)
    }

    @Test func rebuildReplacesOldTriggers() {
        let engine = makeEngine([Snippet(trigger: "old")])
        engine.rebuild(snippets: [Snippet(trigger: "new")], triggerPrefix: ";")
        #expect(engine.match(token: ";old") == nil)
        #expect(engine.match(token: ";new") != nil)
    }
}
