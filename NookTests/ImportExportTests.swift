import Foundation
import Testing
@testable import Nook

struct ImportExportTests {
    private let sampleLibrary = ImportExportTests.makeSampleLibrary()

    private static func makeSampleLibrary() -> SnippetLibrary {
        let folder = SnippetFolder(name: "Dev", sortOrder: 1)
        var snippet = Snippet(
            name: "Component path",
            trigger: "src",
            replacement: "../../components/Button"
        )
        snippet.tags = ["paths", "react"]
        snippet.folderID = folder.id
        var script = Snippet(
            name: "Greeting",
            trigger: "greet",
            replacement: "return \"hi\";\n// second line, with \"quotes\"",
            kind: .script
        )
        script.wholeWordOnly = false
        script.expansionMethod = .clipboard
        return SnippetLibrary(snippets: [snippet, script], folders: [folder])
    }

    @Test func jsonRoundTrip() throws {
        let data = try SnippetDocumentCoder.encode(sampleLibrary, format: .json)
        let decoded = try SnippetDocumentCoder.decode(data)
        #expect(decoded.snippets.map(\.id) == sampleLibrary.snippets.map(\.id))
        #expect(decoded.folders == sampleLibrary.folders)
    }

    @Test func yamlRoundTrip() throws {
        let data = try SnippetDocumentCoder.encode(sampleLibrary, format: .yaml)
        let decoded = try SnippetDocumentCoder.decode(data)

        #expect(decoded.folders.count == 1)
        #expect(decoded.folders[0].name == "Dev")
        #expect(decoded.folders[0].sortOrder == 1)
        #expect(decoded.snippets.count == 2)

        let src = try #require(decoded.snippets.first { $0.trigger == "src" })
        #expect(src.replacement == "../../components/Button")
        #expect(src.tags == ["paths", "react"])
        #expect(src.folderID == sampleLibrary.folders[0].id)

        let greet = try #require(decoded.snippets.first { $0.trigger == "greet" })
        #expect(greet.kind == .script)
        #expect(greet.replacement.contains("\"quotes\""))
        #expect(greet.replacement.contains("\n"))
        #expect(greet.wholeWordOnly == false)
        #expect(greet.expansionMethod == .clipboard)
    }

    @Test func garbageInputThrows() {
        #expect(throws: ImportError.self) {
            try SnippetDocumentCoder.decode(Data("not a snippet file".utf8))
        }
    }
}
