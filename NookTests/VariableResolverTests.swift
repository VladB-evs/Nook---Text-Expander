import Foundation
import Testing
@testable import Nook

struct VariableResolverTests {
    private func makeResolver(clipboard: String = "", selection: String = "") -> VariableResolver {
        // 2026-07-03 12:00:00 UTC, pinned so date output is deterministic.
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = 12
        let date = Calendar(identifier: .gregorian).date(from: components)!
        return VariableResolver(
            now: { date },
            clipboardText: { clipboard },
            selectedText: { selection }
        )
    }

    @Test func resolvesDateVariables() {
        let resolver = makeResolver()
        #expect(resolver.resolve(name: "date") == "2026-07-03")
        #expect(resolver.resolve(name: "year") == "2026")
        #expect(resolver.resolve(name: "month") == "07")
        #expect(resolver.resolve(name: "day") == "03")
        #expect(resolver.resolve(name: "weekday") == "Friday")
    }

    @Test func dateAcceptsCustomFormat() {
        let resolver = makeResolver()
        #expect(resolver.resolve(name: "date", argument: "dd/MM/yyyy") == "03/07/2026")
    }

    @Test func resolvesEnvironmentVariables() {
        let resolver = makeResolver(clipboard: "copied", selection: "selected")
        #expect(resolver.resolve(name: "clipboard") == "copied")
        #expect(resolver.resolve(name: "selection") == "selected")
        #expect(resolver.resolve(name: "username") == NSUserName())
    }

    @Test func uuidIsWellFormed() {
        let resolver = makeResolver()
        let value = resolver.resolve(name: "uuid")
        #expect(value.flatMap(UUID.init(uuidString:)) != nil)
    }

    @Test func unixTimestampMatchesPinnedDate() {
        let resolver = makeResolver()
        let value = resolver.resolve(name: "unix").flatMap(Int.init)
        #expect(value != nil)
        // The pinned date is interpreted in the local calendar; just verify
        // it round-trips to the same instant the resolver was given.
        #expect(value == Int(resolver.now().timeIntervalSince1970))
    }

    @Test func customVariablesResolveCaseInsensitively() {
        let resolver = makeResolver()
        resolver.updateCustomVariables([CustomVariable(name: "Team", value: "Platform")])
        #expect(resolver.resolve(name: "team") == "Platform")
        #expect(resolver.resolve(name: "TEAM") == "Platform")
    }

    @Test func unknownNamesBecomeFillIns() {
        let resolver = makeResolver()
        resolver.updateCustomVariables([CustomVariable(name: "team", value: "Platform")])
        let template = ExpansionTemplate(parsing: "{{client}} / {{date}} / {{team}} / {{client}}")
        #expect(resolver.fillInNames(in: template) == ["client"])
        #expect(resolver.resolve(name: "client") == nil)
    }
}
