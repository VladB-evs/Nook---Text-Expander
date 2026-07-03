import Testing
@testable import Nook

struct ExpansionTemplateTests {
    @Test func plainTextHasSingleLiteral() {
        let template = ExpansionTemplate(parsing: "hello world")
        #expect(template.tokens == [.literal("hello world")])
    }

    @Test func parsesVariables() {
        let template = ExpansionTemplate(parsing: "Meeting on {{date}} at {{time}}")
        #expect(template.variableNames == ["date", "time"])
    }

    @Test func parsesVariableArguments() {
        let template = ExpansionTemplate(parsing: "{{date:dd/MM/yyyy}}")
        #expect(template.tokens == [.variable(name: "date", argument: "dd/MM/yyyy")])
    }

    @Test func pipeBecomesCursorPlaceholder() {
        let template = ExpansionTemplate(parsing: "console.log(|)")
        let resolved = template.render { _, _ in nil }
        #expect(resolved.text == "console.log()")
        #expect(resolved.cursorOffsets == [12])
        #expect(resolved.initialCursorMove == 1)
    }

    @Test func escapedPipeIsLiteral() {
        let template = ExpansionTemplate(parsing: "a \\| b")
        let resolved = template.render { _, _ in nil }
        #expect(resolved.text == "a | b")
        #expect(resolved.cursorOffsets.isEmpty)
    }

    @Test func cursorKeywordAlsoWorks() {
        let template = ExpansionTemplate(parsing: "fn({{cursor}})")
        let resolved = template.render { _, _ in nil }
        #expect(resolved.text == "fn()")
        #expect(resolved.cursorOffsets == [3])
    }

    @Test func multiplePlaceholderOffsets() {
        let template = ExpansionTemplate(parsing: "<a href=\"|\">|</a>")
        let resolved = template.render { _, _ in nil }
        #expect(resolved.text == "<a href=\"\"></a>")
        #expect(resolved.cursorOffsets == [9, 11])
    }

    @Test func renderResolvesVariables() {
        let template = ExpansionTemplate(parsing: "Meeting on {{date}}")
        let resolved = template.render { name, _ in name == "date" ? "2026-07-03" : nil }
        #expect(resolved.text == "Meeting on 2026-07-03")
    }

    @Test func unresolvedVariablesStayVisible() {
        let template = ExpansionTemplate(parsing: "Hi {{who}}")
        let resolved = template.render { _, _ in nil }
        #expect(resolved.text == "Hi {{who}}")
    }

    @Test func placeholderSessionAdvancesByStopDistance() {
        var session = PlaceholderSession(cursorOffsets: [9, 11, 20])
        #expect(session != nil)
        #expect(session?.advance() == 2)
        #expect(session?.advance() == 9)
        #expect(session?.advance() == nil)
    }

    @Test func placeholderSessionRequiresTwoStops() {
        #expect(PlaceholderSession(cursorOffsets: [4]) == nil)
        #expect(PlaceholderSession(cursorOffsets: []) == nil)
    }
}
