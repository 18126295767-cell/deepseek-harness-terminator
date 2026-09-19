# DeepSeek Harness Terminator

**A local-first desktop shell for DeepSeek Harness: launch it like a native Mac app, keep your data on-device, and work with an embedded browser, voice input, tabs, split view, and guarded runtime startup.**

Language / 语言: [简体中文](README.zh-CN.md) · English

This repository contains **DeepSeek Harness Terminator**, a small native AppKit/WebKit shell for the open-source
[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness). It starts
or reconnects to a user-managed local DSH service, displays it in a native
macOS window, and keeps external links in the system browser. The app itself
does not open the Harness as a normal web page.

[上游与范围](UPSTREAM.md) · [许可证](LICENSE)

## See it running

Official DSH Web runtime on an isolated local session:

![Official DeepSeek Harness Web runtime home screen](docs/images/macos-dsh-home.png)

The same local runtime inside the native macOS shell:

![DeepSeek Harness Terminator native macOS app home screen](docs/images/macos-app-home.png)

These are lossless source-resolution PNGs, not recompressed thumbnails. The
[screenshot record](docs/images/README.md) documents capture sources,
dimensions, checksums, and privacy rules. Windows screenshots are produced on
a real `windows-2025` runner and are published only after visual review.

### UI gallery

The release also includes high-resolution, credential-free walkthrough frames:

| Onboarding | Model settings | Plugin inventory |
| --- | --- | --- |
| ![API key onboarding with an empty input](assets/screenshots/macos-02-api-key-onboarding.jpg) | ![Model settings with an empty API key field](assets/screenshots/macos-04-model-settings.jpg) | ![Plugin inventory](assets/screenshots/macos-05-plugin-inventory.jpg) |

The API-key fields are intentionally empty. These images are documentation
fixtures, not a copy of any user's profile or session.

## Included

- Native Swift AppKit window branded as DeepSeek Harness Terminator with the existing DeepSeek Harness visual shell.
- A prebuilt Apple Silicon `DeepSeekHarness.app` for quick local testing.
- WebKit view restricted to the local Harness origin (`127.0.0.1` / `localhost`).
- LaunchAgent helper that starts the local DSH process on demand.
- A fail-closed profile integrity guard that blocks shadow copies of host DSH core packages.
- A Windows companion launcher with portable ZIP and NSIS release targets.
- Chinese macOS menus and startup/error states.
- App icon source files and a reproducible build script.

Not included: DeepSeek API keys, personal phone or email information, npm
dependencies, user sessions, logs, private settings, or the separate plugin
collection. Install and configure the DSH runtime yourself. The Windows
companion is a launcher for the official Web runtime, not a Windows port of
the macOS-only native control plugin.

## Built-in browser

Besides the main session window, the app ships with a **built-in browser panel**
(toggle with `Cmd+B`) for browsing the web in real time without leaving the app.
Unlike a screenshot preview, the panel's `WKWebView` **renders and interacts with
the current page live**, displayed at its original orientation and angle — never
rotated, scaled, or transformed.

Design notes (mapped to the requirements):

- **Real-time, not a screenshot**: the panel loads the page directly as an
  interactive live view that updates as the page changes.
- **Never steals foreground focus**: the panel is shown with `orderFront` rather
  than `makeKeyAndOrderFront`, and it does not call
  `NSApp.activate(ignoringOtherApps:)` on open. The panel uses the `.utilityWindow`
  style with `becomesKeyOnlyIfNeeded = true`, so it only becomes the key window
  when you explicitly click the address field or panel content — the app never
  takes focus away from the frontmost application.
- **Semi-overlapping floating panel**: the panel is an independent utility window
  that floats above the main window and can be resized/repositioned as needed,
  without changing the page's rendered direction or angle.
- **In-app navigation**: `http`, `https`, `view-source`, etc. open inside the
  panel; other schemes (e.g. `mailto`) are handed to the system default app.
  Background/new-window requests load in-panel so no extra window steals focus.
- **Search right in the address bar**: type a URL to open it, or type anything
  else (e.g. `Apple Wallet`) to open the default search engine's results page
  inside the panel — no external browser needed, and independent of the DeepSeek
  official `web_search` API.

Rendering is powered by Apple's open-source WebKit browser engine (`WKWebView`);
see the "Third-party notice: WebKit" section of `NOTICE`.

### Bookmarks and recent history (local-first)

A **☆/★** button in the panel toolbar bookmarks/unbookmarks the current page.
Bookmarks and recent-visit history are stored locally (`UserDefaults`) through
`BrowserSessionStore` (pure Foundation; data never leaves your Mac). Visited
pages are recorded into a capped recent-history for a future command/find bar.
See `docs/competitive-analysis.md` and `docs/requirements-gap-analysis.md` for
the competitor research and requirements gap analysis.

### P0 production features (all landed)

The following P0 roadmap items from the gap analysis are implemented in the
built-in browser:

| Feature | Shortcut | Notes |
| --- | --- | --- |
| Command palette | `⌘T` | Fuzzy-search bookmarks / recent visits / commands; `/` prefix enters command mode (G8); up/down + Enter |
| Find in page | `⌘F` | Live find with previous/next and wrap in the current panel page |
| AI summarize current page | `⌘⇧Y` | Builds a summary prompt (title+URL+text) into the pasteboard and focuses the local DSH |
| Focus address bar | `⌘L` | Move to and select the address field |
| New / close tab | `⌘N` / `⌘W` | New / close the current tab |
| Select tab | `⌘1-9` / `⌘0` | Select a tab by index; `⌘0` picks the last |
| Next tab | `⌃⌘Tab` | Cycle tabs forward |
| Group tabs by site | `⌘⇧G` | Aggregate tabs by host and prefix group names |
| Vertical tab grouping (fold) | within `⌘⇧G` | Per-group collapse/expand; folded groups hide from the bar |
| Split view | `⌘⇧S` | Secondary WKWebView beside the primary for side-by-side reading |
| Session restore | on quit | Tabs + selection + scroll restored on next launch |
| Save current page | menu | Sanitized file name; snapshot PNG to Downloads |
| User scripts | menu / `WKUserScript` | URL-wildcard-matched scripts with CRUD + on/off |
| Mouse gestures (panel) | menu | Panel-local drag→forward/back/refresh; never grabs focus |

All of this logic lives in pure Foundation deep modules (`FindInPageModel`,
`CommandPalette`, `PageSummaryModel`, `TabGroupingModel`, `VerticalTabsModel`,
`SplitPaneState`, `SessionRestoreModel`, `PageCaptureModel`, `UserScriptStore`,
`MouseGestureModel`, `BrowserShortcuts`) covered by driven `swiftc` contract
tests under `tests/`. The only gap intentionally not implemented is G13
(cross-device sync / accounts) to preserve the local-first ethos. The QA
review is recorded in `docs/qa-review.md`.

### Browser panel UI states and accessibility

Navigation state is surfaced in a slim status bar at the bottom of the panel
(`就绪` / `加载中…` / a short failure reason such as `无网络连接`), so long loads
or a failed page never look silent. Every toolbar button (back / forward /
reload / home / mic) carries a `toolTip` and an accessibility label, and the
address field is labelled, so the panel is keyboard- and VoiceOver-friendly.
The panel stays non-intrusive: as before, it appears with `orderFront` and only
becomes the key window when you click inside it.

### Voice input (macOS native, offline)

You can dictate into the active input field without leaving the app:

- **Menu**: *DeepSeek Harness → 语音输入* (`⌘⇧M`), or the **🎤** mic button in the
  built-in browser panel's toolbar.
- **How it works**: on-device `SFSpeechRecognizer` (zh-CN / en-US) transcribes
  locally, then a clipboard bridge pastes the text into the currently focused
  input box. No audio ever leaves your Mac.
- **Feedback**: the mic button / menu item reflect state (`idle` → `listening` →
  `processing`), disabled with a reason when permission or availability fails.
- **Permissions**: the first use prompts for microphone and speech recognition;
  both usage descriptions are declared in `Info.plist`.
- On first use, grant the two permissions in System Settings → Privacy, or the
  entry stays disabled.

Voice output is not duplicated here: the DSH runtime already reads replies aloud
through its own `@dsh-voice` integration (`speak`, backed by macOS `say`).

## Build and install

Requirements: Apple Silicon macOS 12 or newer, Xcode Command Line Tools, Node.js
22 or newer, and a local DeepSeek Harness installation.

```bash
zsh ./scripts/build-app.sh \
  --dsh-runtime /absolute/path/to/dsh-runtime \
  --install
```

The script compiles the Swift shell, creates `DeepSeekHarness.app`, generates a
per-user LaunchAgent with your actual runtime paths, and installs the app under
`~/Applications/DeepSeek Harness Terminator.app`. It does not copy API keys or plugins.

To build without installing:

```bash
zsh ./scripts/build-app.sh --dsh-runtime /absolute/path/to/dsh-runtime
```

The published repository uses the standard source tree: the build entry point
is `scripts/build-app.sh`, Swift sources are under `App/DeepSeekHarnessApp`, and
the LaunchAgent template is under `packaging`. The script also accepts the old
flat export layout for backward compatibility. Run it with `zsh` so the build
does not depend on an executable bit being preserved by an archive download.

See [TUTORIAL.md](TUTORIAL.md) for a complete reproducible setup and
[TUTORIAL.zh-CN.md](TUTORIAL.zh-CN.md) for the Chinese guide.

## Windows companion

Windows 10/11 x64 is supported through the `windows/` companion package. It
starts `@deepseek-ai/dsh` and opens the local Web UI; it does not claim to
provide macOS Automation/Accessibility tools on Windows. Prepare a Windows
machine with `windows/bootstrap-build-environment.ps1`, then build a portable
ZIP, an NSIS per-user installer, and SHA-256 manifest with
`windows/build-release.ps1`. The GitHub Actions workflow runs on a real
`windows-2025` runner and uploads the same artifacts.

Read the [Windows guide](windows/README.md) or
[中文 Windows 指南](windows/README.zh-CN.md) before installing a release.

Windows guide languages: [日本語](windows/README.ja.md) ·
[한국어](windows/README.ko.md) · [Español](windows/README.es.md) ·
[Français](windows/README.fr.md) · [Deutsch](windows/README.de.md) ·
[Português](windows/README.pt-BR.md) · [Русский](windows/README.ru.md) ·
[العربية](windows/README.ar.md) · [हिन्दी](windows/README.hi.md) ·
[繁體中文](windows/README.zh-TW.md).

## Runtime behavior

The app connects to `http://127.0.0.1:3080/` only after the local service is
ready. Closing the app requests termination of the associated LaunchAgent
process. External links are handed to the system browser, while the Harness UI
stays inside the native window.

Before every managed start, `profile-doctor.mjs` compares the selected profile
with the actual runtime. A plugin-provided physical copy of a host
`@deepseek-ai/dsh-*` package is rejected even when its version string matches,
because Cordis services can use copy-local `Symbol` identities. The guard names
the conflicting package and dependency owner, but never deletes files. If a
previous crash already persisted an assistant `tool_calls` message without its
tool result, keep that session as history and retry the task in a new session.

## Attribution and legal notice

This is an independent native shell named **DeepSeek Harness Terminator**, based on the open-source **DeepSeek Harness**
project by **DeepSeek AI**. It is not affiliated with, sponsored by, endorsed by,
or an official product of DeepSeek AI. The upstream project remains separately
licensed under MIT; see [NOTICE](NOTICE) and [UPSTREAM.md](UPSTREAM.md).

## License

The app shell and packaging files in this repository are released under the
[MIT License](LICENSE). A Chinese reference translation is provided in
[LICENSE.zh-CN](LICENSE.zh-CN); the English text controls in case of conflict.
