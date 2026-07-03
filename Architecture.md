# Nook Architecture

Nook is organized as a set of small, independently testable components wired
together by a single composition root. There are no singletons; everything is
constructed in `AppDependencies` and passed down explicitly.

## The expansion pipeline

```
      keystrokes                    CGEventTap (active filter)
          │
          ▼
  KeyboardMonitor          thin CGEventTap wrapper; skips Nook's own
          │                synthetic events (tagged via user-data field)
          ▼
  ExpansionCoordinator     rolling buffer, delimiter detection, pause state,
          │                placeholder Tab-navigation, suggestion routing
          ▼
  SnippetEngine            O(1) dictionary lookup of the typed token
          │                (prefix stripped at match time)
          ▼
  ExpansionEngine          resolves content → deletes trigger → inserts →
          │                re-sends delimiter → returns placeholder session
          ├── ExpansionTemplate   parses {{variables}} and | cursor stops
          ├── VariableResolver    built-ins, custom variables, fill-in detection
          ├── ScriptEngine        pluggable runners (JavaScriptCore today)
          ├── FillInPresenter     non-activating panel for fill-in values
          ├── EventSynthesizer    posts backspaces / typed text / shortcuts
          └── ClipboardManager    snapshot → replace → ⌘V → restore
```

### How one expansion works

1. The user types `;src` and presses Space.
2. The tap callback forwards the keystroke to `ExpansionCoordinator`. Space is
   a delimiter, so the coordinator asks `RollingBuffer` for the trailing token
   (`;src`) and `SnippetEngine` for a match.
3. On a hit, the Space event is **swallowed** (the callback returns nil) and an
   expansion task starts.
4. `ExpansionEngine` renders the template (variables, scripts, fill-ins),
   posts backspaces for the typed length, inserts the replacement — simulated
   typing for short plain text, clipboard paste for long/rich/image content —
   and finally re-sends the swallowed Space.
5. Synthetic events are tagged with a marker in the CGEvent user-data field so
   the tap ignores them; nothing recurses.

All of this happens on the main run loop. The per-keystroke cost is a hash
lookup; the target is well under 10 ms per expansion.

## Modules

| Directory | Contents |
| --- | --- |
| `Nook/Models` | Value types: `Snippet`, `SnippetFolder`, `SnippetLibrary`, `AppSettings`, `LogEntry`. All `Codable` with forward-compatible decoding (unknown keys ignored, missing keys defaulted). |
| `Nook/Services` | The pipeline above plus persistence, permissions, import/export, search, logging. |
| `Nook/Views` | SwiftUI: menu bar menu, main window (sidebar sections), snippet editor. |
| `Nook/Utilities` | `RollingBuffer` and other pure helpers. |
| `NookTests` | Swift Testing suites for every pure component. |

## Key design decisions

**Trigger prefix is app state, not snippet state.** Snippets store `src`, never
`;src`. `SnippetEngine.rebuild` receives the prefix and strips it from typed
tokens at match time, so changing the prefix in settings re-keys nothing.

**Two hash maps for case sensitivity.** Case-sensitive triggers are keyed
verbatim; case-insensitive ones are keyed lowercased. A lookup is at most two
dictionary hits. A sorted trigger list serves prefix queries for the
suggestion popover via binary search.

**The prefix character can't be a delimiter.** `AppSettings.delimiterCharacters`
subtracts the prefix's characters from the configured delimiter set, so a `;`
prefix coexists with `;` in the delimiter list.

**Insertion is strategy-based.** `ExpansionMethodPreference` picks simulated
typing (small text, paste-hostile apps) or clipboard paste (long text, rich
text, images) — per snippet, with an automatic length-threshold default.
`ClipboardManager` snapshots all pasteboard items before a paste and restores
them ~300 ms later; back-to-back expansions keep the original snapshot.

**Cursor placeholders are offset arithmetic.** `ExpansionTemplate` records the
character offsets of `|` stops. After insertion the cursor is moved left to
the first stop with arrow-key events. Because subsequent edits happen only at
the cursor, the distance between consecutive stops is invariant — Tab
navigation (`PlaceholderSession`) is a fixed number of right-arrow presses.

**Isolation model.** Pure logic (`RollingBuffer`, `SnippetEngine`,
`ExpansionTemplate`, `MiniYAML`, persistence) is `nonisolated`. Everything that
touches AppKit or the event system is `@MainActor`. The event-tap C callback
trampolines back onto the main actor, which is safe because the tap is
scheduled on the main run loop.

**Storage is a protocol.** `SnippetPersisting` currently has one JSON
implementation (`~/Library/Application Support/Nook/`). SQLite or cloud sync
can slot in without touching stores or views. Saves are debounced (~400 ms)
and flushed synchronously at quit.

**Safety.** The coordinator checks `IsSecureEventInputEnabled()` on every
keystroke and resets its buffer when secure input is active — Nook never
observes or expands inside password fields. `AccessibilityReader` additionally
exposes a focused-element secure-field check.

## Extension points (for the roadmap)

- **Script languages** — implement `ScriptRunning`, register it with
  `ScriptEngine`. The snippet model already carries a `ScriptLanguage`.
- **Variables** — add a case to `VariableResolver` or inject custom providers;
  fill-in detection automatically excludes anything resolvable.
- **Expansion methods** — `EventSynthesizing` abstracts event output;
  alternative insertion backends implement it.
- **Import/export formats** — `SnippetDocumentCoder` dispatches on
  `SnippetDocumentFormat`; add a case and a codec.
- **Storage backends** — implement `SnippetPersisting`.

These seams exist so cloud sync, AI-generated snippets, plugin marketplaces,
etc. can be added without restructuring the core.

## Testing

`NookTests` uses Swift Testing (`@Test`/`#expect`). System boundaries are
faked: `Pasteboarding` (in-memory pasteboard) and `EventSynthesizing`
(recorded key events) let the clipboard-restoration and full expansion
pipelines run headlessly. Time is injected into `VariableResolver` for
deterministic date output.

```sh
xcodebuild test -scheme Nook -destination 'platform=macOS'
```
