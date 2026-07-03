import Foundation
import JavaScriptCore

nonisolated enum ScriptError: LocalizedError {
    case runnerUnavailable(ScriptLanguage)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .runnerUnavailable(let language):
            "No runner available for \(language.displayName)."
        case .executionFailed(let message):
            "Script failed: \(message)"
        }
    }
}

/// Executes snippet scripts in one language. New languages (Swift, Shell,
/// Python, plugins) are added by registering another runner with the engine.
nonisolated protocol ScriptRunning: Sendable {
    var language: ScriptLanguage { get }
    /// Runs the script and returns its output as the expansion text.
    func run(_ source: String) throws -> String
}

/// Runs JavaScript snippets via JavaScriptCore.
///
/// The source is wrapped in a function body so plain `return` statements work,
/// matching how users expect script snippets to read.
nonisolated struct JavaScriptRunner: ScriptRunning {
    let language = ScriptLanguage.javascript

    func run(_ source: String) throws -> String {
        guard let context = JSContext() else {
            throw ScriptError.executionFailed("Could not create JavaScript context.")
        }
        var exceptionMessage: String?
        context.exceptionHandler = { _, exception in
            exceptionMessage = exception?.toString()
        }
        let result = context.evaluateScript("(function() {\n\(source)\n})()")
        if let exceptionMessage {
            throw ScriptError.executionFailed(exceptionMessage)
        }
        guard let result, !result.isUndefined, !result.isNull else { return "" }
        return result.toString() ?? ""
    }
}

/// Registry that dispatches script snippets to the runner for their language.
nonisolated final class ScriptEngine: @unchecked Sendable {
    private var runners: [ScriptLanguage: any ScriptRunning] = [:]

    init(runners: [any ScriptRunning] = [JavaScriptRunner()]) {
        for runner in runners {
            self.runners[runner.language] = runner
        }
    }

    func register(_ runner: any ScriptRunning) {
        runners[runner.language] = runner
    }

    func run(_ source: String, language: ScriptLanguage) throws -> String {
        guard let runner = runners[language] else {
            throw ScriptError.runnerUnavailable(language)
        }
        return try runner.run(source)
    }
}
