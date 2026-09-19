# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/) and commits follow
[Conventional Commits](https://www.conventionalcommits.org/).

## [Unreleased]

### Added

- **Session restore (G9).** New `SessionRestoreModel` (pure Foundation)
  snapshots tabs + selected index + scroll position into the injected
  `KeyValueStorage`. Saved on app terminate, restored once when the panel
  first opens. Covered by `tests/session-restore.test.swift`.
- **Save current page (G10).** New `PageCaptureModel` (pure Foundation) builds
  a sanitized file name from title/URL and resolves the Downloads directory;
  the panel captures the current view as PNG. Covered by
  `tests/page-capture.test.swift`.
- **Vertical tab grouping with fold (G11).** New `VerticalTabsModel` (pure
  Foundation) groups by injected key, tracks per-group collapse, exposes only
  expanded groups, and supports in-group reorder. Covered by
  `tests/vertical-tabs.test.swift`.
- **Site user scripts (G12).** New `UserScriptStore` (pure Foundation) manages
  script CRUD, active toggle, and URL wildcard matching; matched active scripts
  inject after each page finish. Covered by `tests/user-script.test.swift`.
- **Panel-local mouse gestures (G14).** New `MouseGestureModel` (pure
  Foundation) quantizes drag displacement into a direction and maps it to
  forward/back/refresh; enabled only inside the panel (a local tracking area),
  never a global hook. Covered by `tests/mouse-gesture.test.swift`.
- **Command palette (⌘T).** New `CommandPalette` (pure Foundation: fuzzy
  search by title/subtitle/host, `/` prefix enters command mode, wrap-around
  keyboard navigation) fed by bookmarks + recent visits + commands. A palette
  panel opens on ⌘T and executes open-URL / new-tab / run-command actions.
  Covered by `tests/command-palette.test.swift`.
- **Find in page (⌘F).** New `FindInPageModel` (pure Foundation: query
  normalization, match counting, wrap-around navigation, status text) with a
  find bar using `WKWebView.find(_:configuration:)`. Covered by
  `tests/find-in-page.test.swift`.
- **AI summarize current page (⌘⇧Y).** New `PageSummaryModel` (pure
  Foundation: eligibility + per-language prompt with title/URL/snippet). The
  UI extracts page text via JS, copies the summary prompt, and focuses the
  local DSH. Covered by `tests/page-summary.test.swift`.
- **Keyboard shortcuts.** New `BrowserShortcuts` (pure Foundation: key +
  modifier → command mapping + roadmap coverage). ⌘L, ⌘N, ⌘W, ⌘1-9/⌘0, and
  ⌃⌘Tab menu items target the browser panel. Covered by
  `tests/browser-shortcuts.test.swift`.
- **Tab grouping (⌘⇧G) & split view (⌘⇧S).** New `TabGroupingModel` (group
  tabs by injected key) and `SplitPaneState` (activate/close + mirror-follow).
  The panel groups tab labels by host and shows a secondary WKWebView.
  Covered by `tests/tab-grouping.test.swift` and `tests/split-pane.test.swift`.
- **Bookmarks & recent history (local-first).** New `BrowserSessionStore` (pure
  Foundation; persisted via an injected `KeyValueStorage`, default
  `UserDefaults`). The built-in browser panel gained a **☆/★** bookmark button
  (toggle current page), records a recent-visit history on load, and offers
  `searchBookmarks` for a future command/find bar. Data never leaves the Mac.
  Covered by a new `tests/browser-session.test.swift` (bookmarks, LIFO history
  capping, cross-instance persistence, search), driven by `package.test.mjs`.
- **Voice input (macOS native, offline).** New `VoiceInputModel` (pure
  Foundation: permission state machine, locale normalization, transcript
  normalization) and `VoiceController` (thin `SFSpeechRecognizer` +
  `AVAudioEngine` adapter + clipboard `VoiceBridge`). UI entry points: a
  **语音输入** menu item (`⌘⇧M`) and a **🎤** mic button in the built-in
  browser panel. Mic button and menu reflect `idle → listening → processing`
  state and disable with a reason when permission/availability fails.
  `Info.plist` now declares `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription`.
- **Browser panel UI states and accessibility.** A bottom status bar shows
  `就绪` / `加载中…` / navigation-failure reasons (e.g. `无网络连接`) instead of
  silent stalls. Every toolbar button gained a `toolTip` and accessibility
  label; the address field is labelled for VoiceOver.
- **Reproducible verification scripts.** `npm run typecheck` (Swift
  `-typecheck` across all sources) and `npm run lint` (a dependency-free repo
  lint for TODO/FIXME leftovers, build wiring, plist permission keys, and test
  coverage). `build-app.sh` now localizes the clang module cache under the
  output dir for deterministic, permission-safe builds.
- **Competitor research & requirements gap analysis.** `docs/competitive-analysis.md`
  and `docs/requirements-gap-analysis.md` document the desktop-AI-browser
  landscape (Arc / SigmaOS / Sidekick / Floorp / Orion / Raycast / desktop AI
  clients) and the prioritized gaps to close.

### Changed

- `build-app.sh` and `npm run typecheck` now compile `VoiceInputModel.swift`,
  `VoiceController.swift`, `BrowserTabManager.swift`, and
  `BrowserSessionStore.swift` alongside `main.swift`, linking `Speech` and
  `AVFoundation`.
- `scripts/lint.mjs` checks that every Swift source is compiled by the build and
  covered by a driven test.
- The G11 group-header fold button carries its group name directly in its
  `NSUserInterfaceItemIdentifier` instead of decoding it from the display label
  (`dropFirst`) — the identifier no longer breaks if the label text changes.

### Fixed

- `main.swift` previously did not compile: `buildPanel` referenced an undefined
  `statusBar`. The browser panel status label is now added to the layout
  (`pageStatusLabel`), and dead `webRect`/unused `config` scaffolding was
  removed. `BrowserTabManager.swift` and `BrowserSessionStore.swift` are now
  wired into `build-app.sh`, `npm run typecheck`, `lint`, and the node test
  suite.
- **Adversarial QA findings (12 issues from `checkup`, all red-team confirmed):**
  - G14 panel mouse gestures are now actually wired: a panel-scoped local
    `NSEvent` monitor runs drag gestures through `MouseGestureModel` into
    forward/back/refresh, and the monitor is removed on toggle-off (no tracking-
    area accumulation).
  - G9 session restore no longer spawns a spurious default tab, saves
    synchronously on quit (no async-save race), and loads every restored tab.
  - G11 grouped tab bar renders a foldable, clickable group header (identifier
    carries the real group name rather than decoding the display label), and no
    longer shows a literal ternary expression.
  - G12 user scripts gained a management entry ("Add user script…") and inject
    deduped per webView+URL.
  - G10 page saves use `PageCaptureModel.uniqueFileName` (`-1/-2/…`) so repeated
    captures never silently overwrite.
  - "AI summarize" asks before writing to the clipboard and trims the snippet,
    protecting the user's clipboard and sensitive page content.

### Security

- Voice transcription happens entirely on-device; no audio is uploaded.