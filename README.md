# Nook

**System-wide text expansion for macOS that stays out of your way.**

Nook is a native menu bar utility. Define short triggers, type them anywhere —
Safari, Xcode, Slack, Terminal, any standard text input — and Nook instantly
replaces them with your snippet.

```
;src⎵   →   ../../components/Button⎵
```

## Features

- **Works everywhere** — global keyboard monitoring via CGEventTap; expansion
  works in any app that accepts keyboard input.
- **Configurable trigger prefix** — `;` by default, change it to `:`, `/`, `//`,
  `::`, `!!`, or anything else. The prefix is a global setting; changing it
  instantly applies to every snippet.
- **Snippet types** — plain text, rich text, images, and JavaScript snippets
  whose return value becomes the expansion.
- **Dynamic variables** — `{{date}}`, `{{time}}`, `{{uuid}}`, `{{clipboard}}`,
  `{{selection}}`, and more, plus your own custom variables.
- **Fill-in prompts** — unknown variables like `{{client}}` pop up a small form
  before expanding.
- **Cursor placeholders** — `console.log(|)` puts the cursor between the
  parentheses; multiple `|` stops are reachable with Tab.
- **Suggestions** *(optional)* — a small popover lists matching triggers while
  you type; navigate with ↑↓, accept with Return.
- **Organization** — folders, tags, favorites, instant search, per-snippet
  enable/disable, JSON and YAML import/export.
- **Safe by design** — expansion is automatically suspended in password fields
  and whenever macOS Secure Input is active. Nook never stores what you type.
- **Lightweight** — no Dock icon, near-zero idle CPU, tiny memory footprint,
  snippet lookup is O(1).

## Requirements

- macOS 26.5 or later
- Xcode 26 to build from source

## Building

```sh
git clone <repository-url>
cd Nook
open Nook.xcodeproj      # build & run the "Nook" scheme
```

or from the command line:

```sh
xcodebuild build -scheme Nook -destination 'platform=macOS'
xcodebuild test  -scheme Nook -destination 'platform=macOS'
```

## First launch

Nook needs two privacy permissions to work:

1. **Accessibility** — to remove typed triggers and insert replacements.
2. **Input Monitoring** — to observe keystrokes and detect triggers.

On first launch Nook opens its Permissions screen and guides you through
granting both in System Settings → Privacy & Security. Optionally enable
**Launch at Login** so Nook is always ready.

> Note: after granting Accessibility for a rebuilt/self-signed build you may
> need to remove and re-add Nook in System Settings.

## Usage

1. Click the menu bar icon → **Open Nook** to manage snippets.
2. Create a snippet — e.g. trigger `email`, replacement `you@example.com`.
3. In any app, type `;email` followed by Space (or Return, Tab, `.` …).
4. Watch it expand.

Pause expansion for 5 minutes, 15 minutes, or an hour from the menu bar, or
disable it entirely. The icon reflects the current state.

### Snippet syntax

| Syntax | Meaning |
| --- | --- |
| `{{date}}`, `{{time}}`, `{{datetime}}` | current date/time (`{{date:dd MMM yyyy}}` for custom formats) |
| `{{year}}` `{{month}}` `{{day}}` `{{weekday}}` | date components |
| `{{uuid}}` `{{random}}` `{{unix}}` | generated values |
| `{{hostname}}` `{{username}}` | machine info |
| `{{clipboard}}` `{{selection}}` | current clipboard / selected text |
| `{{anythingElse}}` | fill-in prompt shown at expansion time |
| `\|` or `{{cursor}}` | cursor position after expansion (`\\\|` for a literal pipe) |

Snippets are stored as human-readable JSON in
`~/Library/Application Support/Nook/`.

## Documentation

- [Architecture.md](Architecture.md) — how the pieces fit together
- [Contributing.md](Contributing.md) — developer setup and guidelines

## License

Open source. License to be finalized before the first public release.
