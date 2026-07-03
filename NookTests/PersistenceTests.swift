import Foundation
import Testing
@testable import Nook

struct PersistenceTests {
    private func temporaryPersistence() -> JSONPersistence {
        JSONPersistence(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("NookTests-\(UUID().uuidString)", isDirectory: true)
        )
    }

    @Test func libraryRoundTrips() throws {
        let persistence = temporaryPersistence()
        let folder = SnippetFolder(name: "Work")
        var snippet = Snippet(name: "Sig", trigger: "sig", replacement: "Best,\nVlad")
        snippet.tags = ["mail", "work"]
        snippet.folderID = folder.id
        snippet.isCaseSensitive = true

        try persistence.saveLibrary(SnippetLibrary(snippets: [snippet], folders: [folder]))
        let loaded = try #require(try persistence.loadLibrary())

        #expect(loaded.snippets.count == 1)
        #expect(loaded.snippets[0].id == snippet.id)
        #expect(loaded.snippets[0].replacement == "Best,\nVlad")
        #expect(loaded.snippets[0].tags == ["mail", "work"])
        #expect(loaded.snippets[0].isCaseSensitive)
        #expect(loaded.folders == [folder])
    }

    @Test func settingsRoundTrip() throws {
        let persistence = temporaryPersistence()
        var settings = AppSettings()
        settings.triggerPrefix = "//"
        settings.suggestionsEnabled = true
        settings.customVariables = [CustomVariable(name: "team", value: "Platform")]

        try persistence.saveSettings(settings)
        let loaded = try #require(try persistence.loadSettings())
        #expect(loaded == settings)
    }

    @Test func missingFilesLoadAsNil() throws {
        let persistence = temporaryPersistence()
        #expect(try persistence.loadLibrary() == nil)
        #expect(try persistence.loadSettings() == nil)
    }

    @Test func snippetStorePersistsMutations() throws {
        let persistence = temporaryPersistence()
        let store = SnippetStore(persistence: persistence)
        let snippet = Snippet(name: "Test", trigger: "tt", replacement: "value")
        store.add(snippet)
        store.persistNow()

        let reloaded = SnippetStore(persistence: persistence)
        #expect(reloaded.snippet(withID: snippet.id)?.trigger == "tt")
    }

    @Test func snippetStoreDeleteRemovesAndPersists() throws {
        let persistence = temporaryPersistence()
        let store = SnippetStore(persistence: persistence)
        let snippet = Snippet(trigger: "gone")
        store.add(snippet)
        store.delete([snippet.id])
        store.persistNow()

        let reloaded = SnippetStore(persistence: persistence)
        #expect(reloaded.snippet(withID: snippet.id) == nil)
    }

    @Test func settingsStoreDecodingToleratesUnknownAndMissingKeys() throws {
        let persistence = temporaryPersistence()
        try FileManager.default.createDirectory(at: persistence.directory, withIntermediateDirectories: true)
        let partialJSON = ##"{"triggerPrefix": "#", "futureUnknownKey": 42}"##
        try Data(partialJSON.utf8).write(to: persistence.directory.appendingPathComponent("settings.json"))

        let loaded = try #require(try persistence.loadSettings())
        #expect(loaded.triggerPrefix == "#")
        #expect(loaded.isEnabled == AppSettings().isEnabled)
    }
}
