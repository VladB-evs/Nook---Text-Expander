# Contributing to Nook

Thanks for helping make Nook better. This document covers developer setup and
the conventions the codebase follows.

## Setup

1. Install Xcode 26 or later.
2. Clone and open:
   ```sh
   git clone <repository-url>
   cd Nook
   open Nook.xcodeproj
   ```
3. Run the `Nook` scheme. On first launch, grant **Accessibility** and
   **Input Monitoring** in System Settings when prompted.

No external dependencies; the project builds with the system SDK only.

### Development tips

- **Permissions and rebuilds:** macOS ties privacy grants to the code
  signature. If expansion stops working after a rebuild, remove Nook from
  System Settings → Privacy & Security → Accessibility and re-add it.
- **Debug console:** enable *Advanced → Debug logging* to watch trigger
  detection, expansion timings, and clipboard operations live.
- **Data location:** snippets and settings live in
  `~/Library/Application Support/Nook/` as pretty-printed JSON. Delete the
  folder to reset to first-launch state.

## Running tests

```sh
xcodebuild test -scheme Nook -destination 'platform=macOS'
```

Tests use [Swift Testing](https://developer.apple.com/documentation/testing)
(`@Test`, `#expect`). Every pure component has a suite; system boundaries
(pasteboard, event posting) have fake implementations in `NookTests`.

Please add tests for any change to matching, template parsing, variable
resolution, persistence, or import/export.

## Code conventions

- Modern Swift with structured concurrency. UI and system-facing services are
  `@MainActor`; pure logic is `nonisolated` and kept free of AppKit imports
  where possible.
- Dependency injection over globals: everything is constructed in
  `AppDependencies` and passed explicitly. Don't add singletons.
- Small, focused types. If a view or service grows past a couple of screens,
  split it.
- Comments explain *why*, not *what*. Doc comments on types; sparse comments
  inside function bodies.
- No new dependencies without prior discussion.

## Architecture

Read [Architecture.md](Architecture.md) before touching the expansion
pipeline. In particular:

- Snippet triggers never contain the prefix.
- Trigger lookup must stay O(1) — never iterate all snippets on a keystroke.
- Synthetic events must be tagged (see `EventSynthesizer.syntheticMarker`) so
  the event tap ignores them.
- Anything that could run while the user types must be allocation-light and
  fast; the per-keystroke budget is effectively zero.

## Safety rules

These are non-negotiable for any contribution:

- Never observe or expand while Secure Input is active or a password field is
  focused.
- Never persist raw keystroke data. The rolling buffer is in-memory, bounded,
  and reset on focus changes.
- Never attempt to bypass or work around macOS privacy mechanisms.

## Pull requests

1. Branch from `main`.
2. Keep PRs focused; unrelated refactors go in separate PRs.
3. `xcodebuild build` and `xcodebuild test` must pass with zero warnings.
4. Describe user-visible behavior changes in the PR body.
