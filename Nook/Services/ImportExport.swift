import Foundation

nonisolated enum SnippetDocumentFormat: String, CaseIterable, Sendable {
    case json
    case yaml

    var fileExtension: String { rawValue }
}

nonisolated enum ImportError: LocalizedError {
    case unrecognizedFormat

    var errorDescription: String? {
        "The file is not a recognized Nook snippet export (JSON or YAML)."
    }
}

/// Encodes and decodes snippet libraries for import/export.
/// Import auto-detects the format, so exports from either encoder round-trip.
nonisolated enum SnippetDocumentCoder {
    static func encode(_ library: SnippetLibrary, format: SnippetDocumentFormat) throws -> Data {
        switch format {
        case .json:
            return try JSONPersistence.encoder.encode(library)
        case .yaml:
            return Data(MiniYAML.encode(library).utf8)
        }
    }

    static func decode(_ data: Data) throws -> SnippetLibrary {
        if let library = try? JSONPersistence.decoder.decode(SnippetLibrary.self, from: data) {
            return library
        }
        guard let text = String(data: data, encoding: .utf8),
              let library = MiniYAML.decode(text)
        else {
            throw ImportError.unrecognizedFormat
        }
        return library
    }
}

/// A deliberately small YAML dialect for snippet exports: two top-level
/// sequences (`folders:` and `snippets:`) of flat mappings whose string
/// values are always double-quoted with JSON escaping. Not a general YAML
/// parser — just enough to round-trip Nook's own exports and hand-edited
/// files in the same shape.
nonisolated enum MiniYAML {
    // MARK: - Encoding

    static func encode(_ library: SnippetLibrary) -> String {
        var lines: [String] = ["# Nook snippet export"]
        lines.append("folders:")
        for folder in library.folders {
            lines.append("  - id: \(quote(folder.id.uuidString))")
            lines.append("    name: \(quote(folder.name))")
            lines.append("    sortOrder: \(folder.sortOrder)")
        }
        lines.append("snippets:")
        for snippet in library.snippets {
            lines.append("  - id: \(quote(snippet.id.uuidString))")
            lines.append("    name: \(quote(snippet.name))")
            lines.append("    trigger: \(quote(snippet.trigger))")
            lines.append("    replacement: \(quote(snippet.replacement))")
            lines.append("    kind: \(quote(snippet.kind.rawValue))")
            lines.append("    scriptLanguage: \(quote(snippet.scriptLanguage.rawValue))")
            if let rtf = snippet.rtfData {
                lines.append("    rtfData: \(quote(rtf.base64EncodedString()))")
            }
            if let image = snippet.imageData {
                lines.append("    imageData: \(quote(image.base64EncodedString()))")
            }
            if !snippet.tags.isEmpty {
                lines.append("    tags: [\(snippet.tags.map(quote).joined(separator: ", "))]")
            }
            if let folderID = snippet.folderID {
                lines.append("    folderID: \(quote(folderID.uuidString))")
            }
            lines.append("    isEnabled: \(snippet.isEnabled)")
            lines.append("    isFavorite: \(snippet.isFavorite)")
            lines.append("    isCaseSensitive: \(snippet.isCaseSensitive)")
            lines.append("    wholeWordOnly: \(snippet.wholeWordOnly)")
            lines.append("    expansionMethod: \(quote(snippet.expansionMethod.rawValue))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func quote(_ string: String) -> String {
        var result = "\""
        for character in string.unicodeScalars {
            switch character {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if character.value < 0x20 {
                    result += String(format: "\\u%04X", character.value)
                } else {
                    result.unicodeScalars.append(character)
                }
            }
        }
        return result + "\""
    }

    // MARK: - Decoding

    static func decode(_ text: String) -> SnippetLibrary? {
        enum Section { case none, folders, snippets }
        var section = Section.none
        var items: [(Section, [String: String])] = []
        var current: [String: String]?

        func flush() {
            if let current, section != .none {
                items.append((section, current))
            }
            current = nil
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if line == "folders:" {
                flush()
                section = .folders
            } else if line == "snippets:" {
                flush()
                section = .snippets
            } else if trimmed.hasPrefix("- ") {
                flush()
                current = [:]
                if let (key, value) = parseKeyValue(String(trimmed.dropFirst(2))) {
                    current?[key] = value
                }
            } else if current != nil, let (key, value) = parseKeyValue(trimmed) {
                current?[key] = value
            } else if section == .none {
                return nil
            }
        }
        flush()

        guard items.contains(where: { $0.0 == .snippets }) else { return nil }

        var library = SnippetLibrary()
        for (itemSection, fields) in items {
            switch itemSection {
            case .folders:
                guard let name = fields["name"] else { continue }
                library.folders.append(SnippetFolder(
                    id: fields["id"].flatMap(UUID.init(uuidString:)) ?? UUID(),
                    name: name,
                    sortOrder: fields["sortOrder"].flatMap(Int.init) ?? 0
                ))
            case .snippets:
                guard let trigger = fields["trigger"] else { continue }
                var snippet = Snippet(
                    id: fields["id"].flatMap(UUID.init(uuidString:)) ?? UUID(),
                    name: fields["name"] ?? "",
                    trigger: trigger,
                    replacement: fields["replacement"] ?? "",
                    kind: fields["kind"].flatMap(SnippetKind.init(rawValue:)) ?? .text
                )
                snippet.scriptLanguage = fields["scriptLanguage"].flatMap(ScriptLanguage.init(rawValue:)) ?? .javascript
                snippet.rtfData = fields["rtfData"].flatMap { Data(base64Encoded: $0) }
                snippet.imageData = fields["imageData"].flatMap { Data(base64Encoded: $0) }
                snippet.tags = fields["tags"].map(parseInlineList) ?? []
                snippet.folderID = fields["folderID"].flatMap(UUID.init(uuidString:))
                snippet.isEnabled = fields["isEnabled"].map { $0 == "true" } ?? true
                snippet.isFavorite = fields["isFavorite"].map { $0 == "true" } ?? false
                snippet.isCaseSensitive = fields["isCaseSensitive"].map { $0 == "true" } ?? false
                snippet.wholeWordOnly = fields["wholeWordOnly"].map { $0 == "true" } ?? true
                snippet.expansionMethod = fields["expansionMethod"].flatMap(ExpansionMethodPreference.init(rawValue:)) ?? .automatic
                library.snippets.append(snippet)
            case .none:
                break
            }
        }
        return library
    }

    /// Splits `key: value`, unquoting the value when it is a quoted scalar.
    private static func parseKeyValue(_ line: String) -> (String, String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
        let rawValue = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        return (key, unquote(rawValue))
    }

    private static func unquote(_ value: String) -> String {
        guard value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 else { return value }
        let inner = value.dropFirst().dropLast()
        var result = ""
        var iterator = inner.makeIterator()
        while let character = iterator.next() {
            guard character == "\\" else {
                result.append(character)
                continue
            }
            switch iterator.next() {
            case "n": result.append("\n")
            case "r": result.append("\r")
            case "t": result.append("\t")
            case "\"": result.append("\"")
            case "\\": result.append("\\")
            case "u":
                var hex = ""
                for _ in 0..<4 {
                    if let digit = iterator.next() { hex.append(digit) }
                }
                if let value = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(value) {
                    result.unicodeScalars.append(scalar)
                }
            case let other?:
                result.append(other)
            case nil:
                break
            }
        }
        return result
    }

    private static func parseInlineList(_ value: String) -> [String] {
        guard value.hasPrefix("["), value.hasSuffix("]") else { return [] }
        let inner = value.dropFirst().dropLast()
        var items: [String] = []
        var currentItem = ""
        var inQuotes = false
        var escaped = false
        for character in inner {
            if escaped {
                currentItem.append("\\")
                currentItem.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                inQuotes.toggle()
                currentItem.append(character)
            } else if character == "," && !inQuotes {
                items.append(currentItem)
                currentItem = ""
            } else {
                currentItem.append(character)
            }
        }
        if !currentItem.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(currentItem)
        }
        return items.map { unquote($0.trimmingCharacters(in: .whitespaces)) }.filter { !$0.isEmpty }
    }
}
