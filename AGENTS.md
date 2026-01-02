# ButlerAI Agent Notes

## Product Overview
ButlerAI is a macOS menubar app that improves selected text using AI. It runs without a dock icon, listens for a global hotkey (⌃⌥⌘C), copies the current selection, sends it to an AI backend (OpenAI or local Ollama), then pastes the improved text back while preserving clipboard contents.

## High-Level Architecture
- **UI shell:** SwiftUI `MenuBarExtra` with settings and logs windows.
- **State orchestration:** `AppState` coordinates services, processing state, errors, and window lifecycle.
- **Services layer:** Hotkey handling, clipboard operations, AI requests, language handling, logging.
- **Settings persistence:** `@AppStorage` in `SettingsService` for backend selection and configuration.

## Key Components
- `Butler/ButlerApp.swift`
  - `AppState` owns `HotkeyManager`, `ClipboardManager`, `OpenAIService`, `LanguageService`, `SettingsService`.
  - Handles menu bar UI, settings window, log window, and end-to-end “improve text” flow.
  - Uses `MenuBarExtra` with animated icon during processing.

- `Butler/Services/HotkeyManager.swift`
  - Watches accessibility permission with a 2s timer.
  - Uses a global keyboard monitor to detect ⌃⌥⌘C.
  - Shows a permission prompt and opens System Settings when needed.

- `Butler/Services/ClipboardManager.swift`
  - Simulates **Cmd+C** to capture selection and **Cmd+V** to paste.
  - Preserves and restores previous clipboard contents.
  - Uses `CGEvent` and short sleeps to allow pasteboard updates.

- `Butler/Services/OpenAIService.swift`
  - Supports **OpenAI** and **Ollama** backends.
  - OpenAI endpoint: `.../v1/chat/completions` (supports custom base URL).
  - Ollama endpoint: `.../api/chat`; models list: `.../api/tags`.
  - Sends a system prompt + user content message array.

- `Butler/Services/LanguageService.swift`
  - Detects Italian text using `NaturalLanguage`.
  - If Italian, asks the AI to translate and improve; otherwise improves directly.

- `Butler/Services/LoggerService.swift` + `Butler/Views/LogView.swift`
  - In-memory structured logs with type (info/warning/error).
  - Log window supports search, filtering, auto-scroll, copy, clear.

- `Butler/Views/SettingsView.swift`
  - Backend switcher (OpenAI vs Ollama).
  - OpenAI key input; Ollama URL + model picker with refresh.
  - Improvement prompt editor.

- `Butler/Models/AIConfiguration.swift`
  - `AIBackendType` enum.
  - Default model constant: `gpt-4o-mini`.

## Data Flow (Runtime)
1. User presses ⌃⌥⌘C.
2. `HotkeyManager` triggers `AppState.improveSelectedText()`.
3. `ClipboardManager` captures selection via Cmd+C.
4. `LanguageService` optionally translates Italian and calls `OpenAIService`.
5. Improved text returned to `ClipboardManager` for Cmd+V paste.
6. Previous clipboard contents are restored.

## Settings & Persistence
`SettingsService` stores:
- `openaiKey`
- `aiBackend` (OpenAI / Ollama)
- `ollamaURL` (also reused as a custom OpenAI base URL when backend is OpenAI and URL is non-default)
- `selectedModel`
- `improvementPrompt`

## Permissions & OS Integration
- Requires **Accessibility** permissions for global key monitoring and clipboard events.
- Uses `AXIsProcessTrustedWithOptions` for prompting and `NSEvent.addGlobalMonitorForEvents` for hotkey capture.

## Observed Quirks / Implementation Notes
- `ClipboardManager` still uses `print()` for logging, while other areas use `LoggerService`.
- OpenAI base URL customization piggybacks on `ollamaURL` when backend is OpenAI and URL differs from `http://localhost:11434`.
- AI request uses a chat payload with `system` and `user` messages and a fixed `temperature: 0.7`.

## Build & Test
- Open `Butler.xcodeproj` in Xcode (macOS 12+).
- Tests live in `ButlerTests` (UI tests removed).

## Common Entry Points
- App: `Butler/ButlerApp.swift`
- AI: `Butler/Services/OpenAIService.swift`
- Settings: `Butler/Views/SettingsView.swift`
- Clipboard: `Butler/Services/ClipboardManager.swift`
- Hotkey: `Butler/Services/HotkeyManager.swift`
- Logs UI: `Butler/Views/LogView.swift`

# unit tests
Use XCTest for unit tests.
Implement unit tests to ensure that the code works as intended.
Run the tests before making any changes, add tests to verify the changes, and ensure that the tests pass before considering the session complete.

# xcodebuild 
To save context, use the tool xcsift to format the output of xcodebuild or Swift. 
Here is the help:
OVERVIEW: A Swift tool to parse and format xcodebuild output for coding agents
xcsift reads xcodebuild output from stdin and outputs structured JSON.
Important: Always use 2>&1 to redirect stderr to stdout. This ensures all
compiler errors, warnings, and build output are captured.
Examples:
xcodebuild build 2>&1 | xcsift -w
xcodebuild test 2>&1 | xcsift -w
swift build 2>&1 | xcsift -w
swift test 2>&1 | xcsift -w

# Structure hygiene
Fix all errors, warnings, and failed tests, even if they are not related to the current changes being made.

# grep or search text 
You are operating in an environment where ast-grep is installed. For any code search that requires understanding of syntax or code structure, you should default to using ast-grep --lang [language] -p '<pattern>'. Adjust the --lang flag as needed for the specific programming language. Avoid using text-only search tools unless a plain-text search is explicitly requested.

# tests scope
UI tests have been removed; unit tests are run via `make test`.

# Makefile
Use `Makefile` targets for common tasks:
- `make test` (unit tests only, executes tests)
- `make test-build` (build-for-testing only)
- `make build`
- `make archive`
- `make clean`

# test command
Use `make test` to execute unit tests (includes xcsift formatting and validates that the log includes the test count; prints `tests_run`).
