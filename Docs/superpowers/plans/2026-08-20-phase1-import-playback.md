# Phase 1: Video Import & Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user pick a local video file (via file picker or by pasting a path/file:// URL) and preview it with basic play/pause and a time/duration readout.

**Architecture:** SwiftUI app with an AppKit bridge (`NSViewRepresentable`) wrapping `AVPlayerView` for playback, a `PlayerViewModel` (`@Observable`, `@MainActor`) owning the `AVPlayer` and publishing playback state, and a `VideoImportService` providing pure, testable URL/path resolution logic used by both the `NSOpenPanel` flow and the paste-path flow.

**Tech Stack:** Swift, SwiftUI, AppKit (`AVPlayerView` bridge), AVFoundation (`AVPlayer`, `AVURLAsset`), Swift Testing.

**Spec:** `Docs/DEVELOPMENT_PLAN.md` (sections 3.1, 3.2, 5.1, 7 Phase 1)

## Global Constraints

- Minimum deployment target: macOS 26 (Tahoe)+.
- Swift/SwiftUI only for UI; AppKit only via bridges where SwiftUI has no equivalent (`AVPlayerView`).
- No force-unwraps; use `guard let` / optional chaining.
- All new Swift files use `[weak self]` in any escaping closures that capture a reference type.
- Tests use Swift Testing (`@Test`, `#expect`), not XCTest.
- Xcode project uses file-system-synchronized groups — files created on disk under `VideoClipperApp/`, `VideoClipperAppTests/` are auto-added to the project; no manual project-file editing needed.
- Build/test via `xcodebuild -scheme VideoClipperApp -destination 'platform=macOS'` (or the `mcp__xcode__BuildProject` / `RunAllTests` tools against the already-open workspace).

---

## File Structure

```
VideoClipperApp/
├── Sources/
│   ├── App/
│   │   ├── VideoClipperAppApp.swift   (moved from VideoClipperApp/VideoClipperAppApp.swift)
│   │   └── ContentView.swift          (moved from VideoClipperApp/ContentView.swift)
│   ├── Models/
│   │   └── (empty for Phase 1; ClipSegment/TimelineState land in Phase 2)
│   ├── ViewModels/
│   │   └── PlayerViewModel.swift
│   ├── Views/
│   │   └── PlayerContainerView.swift  (NSViewRepresentable wrapping AVPlayerView)
│   ├── Services/
│   │   └── VideoImportService.swift
│   └── Utilities/
│       └── TimeFormatter.swift
VideoClipperAppTests/
├── VideoImportServiceTests.swift
├── PlayerViewModelTests.swift
└── TimeFormatterTests.swift
```

---

### Task 1: Reorganize source tree into `Sources/` layout

**Files:**
- Move: `VideoClipperApp/VideoClipperAppApp.swift` → `VideoClipperApp/Sources/App/VideoClipperAppApp.swift`
- Move: `VideoClipperApp/ContentView.swift` → `VideoClipperApp/Sources/App/ContentView.swift`
- Create (empty dirs will be created by later tasks writing into them): `VideoClipperApp/Sources/Models/`, `VideoClipperApp/Sources/ViewModels/`, `VideoClipperApp/Sources/Views/`, `VideoClipperApp/Sources/Services/`, `VideoClipperApp/Sources/Utilities/`

**Interfaces:**
- Produces: `ContentView` (SwiftUI `View`), `VideoClipperAppApp` (`App`) — unchanged public shape, only file location changes.

- [ ] **Step 1: Move the two existing files**

```bash
mkdir -p VideoClipperApp/Sources/App
git mv VideoClipperApp/VideoClipperAppApp.swift VideoClipperApp/Sources/App/VideoClipperAppApp.swift
git mv VideoClipperApp/ContentView.swift VideoClipperApp/Sources/App/ContentView.swift
```

- [ ] **Step 2: Build to confirm the file-system-synchronized group still picks up the moved files**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: move app entry files into Sources/App layout"
```

---

### Task 2: `TimeFormatter` utility (mm:ss / h:mm:ss formatting)

**Files:**
- Create: `VideoClipperApp/Sources/Utilities/TimeFormatter.swift`
- Test: `VideoClipperAppTests/TimeFormatterTests.swift`

**Interfaces:**
- Produces: `enum TimeFormatter { static func string(from seconds: Double) -> String }` — used by Task 3's `PlayerViewModel` display state and Task 6's `ContentView` time label.

- [ ] **Step 1: Write the failing tests**

```swift
// VideoClipperAppTests/TimeFormatterTests.swift
import Testing
@testable import VideoClipperApp

struct TimeFormatterTests {

    @Test func zeroSeconds_formatsAsZeroZero() {
        #expect(TimeFormatter.string(from: 0) == "00:00")
    }

    @Test func underOneMinute_formatsAsMinutesSeconds() {
        #expect(TimeFormatter.string(from: 45) == "00:45")
    }

    @Test func overOneHour_formatsWithHours() {
        #expect(TimeFormatter.string(from: 3725) == "1:02:05")
    }

    @Test func negativeSeconds_clampsToZero() {
        #expect(TimeFormatter.string(from: -5) == "00:00")
    }

    @Test func nanSeconds_clampsToZero() {
        #expect(TimeFormatter.string(from: .nan) == "00:00")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' test -only-testing:VideoClipperAppTests/TimeFormatterTests`
Expected: FAIL — `TimeFormatter` does not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
// VideoClipperApp/Sources/Utilities/TimeFormatter.swift
import Foundation

enum TimeFormatter {
    static func string(from seconds: Double) -> String {
        let clamped = seconds.isFinite ? max(0, seconds) : 0
        let totalSeconds = Int(clamped.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' test -only-testing:VideoClipperAppTests/TimeFormatterTests`
Expected: all 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add VideoClipperApp/Sources/Utilities/TimeFormatter.swift VideoClipperAppTests/TimeFormatterTests.swift
git commit -m "feat: add TimeFormatter utility for mm:ss / h:mm:ss display"
```

---

### Task 3: `VideoImportService` — resolve file-picker and pasted-path input into a playable URL

**Files:**
- Create: `VideoClipperApp/Sources/Services/VideoImportService.swift`
- Test: `VideoClipperAppTests/VideoImportServiceTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `enum VideoImportError: Error, Equatable { case emptyInput, fileNotFound, unsupportedFormat, notAFileURL }`
  - `struct VideoImportService { func resolveVideoURL(fromPastedText text: String, fileManager: FileManager = .default) -> Result<URL, VideoImportError>` }`
  - `func presentOpenPanel(allowedContentTypes: [UTType]) -> URL?` (thin NSOpenPanel wrapper, not unit tested — excluded from the test file, exercised manually in Task 6).
  - Consumed by Task 6's `ContentView` for both the "choose file" button and the "paste path" text field.

- [ ] **Step 1: Write the failing tests**

```swift
// VideoClipperAppTests/VideoImportServiceTests.swift
import Testing
import Foundation
@testable import VideoClipperApp

struct VideoImportServiceTests {

    @Test func emptyString_returnsEmptyInputError() {
        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: "")
        #expect(result == .failure(.emptyInput))
    }

    @Test func whitespaceOnlyString_returnsEmptyInputError() {
        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: "   \n  ")
        #expect(result == .failure(.emptyInput))
    }

    @Test func fileURLStringForExistingFile_returnsURL() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).mov")
        FileManager.default.createFile(atPath: tempURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: tempURL.absoluteString)

        #expect(result == .success(tempURL))
    }

    @Test func plainPathStringForExistingFile_returnsURL() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: tempURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: tempURL.path)

        #expect(result == .success(tempURL))
    }

    @Test func nonExistentPath_returnsFileNotFoundError() {
        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: "/tmp/does-not-exist-\(UUID().uuidString).mp4")
        #expect(result == .failure(.fileNotFound))
    }

    @Test func httpURLString_returnsNotAFileURLError() {
        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: "https://example.com/video.mp4")
        #expect(result == .failure(.notAFileURL))
    }

    @Test func unsupportedExtension_returnsUnsupportedFormatError() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: tempURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: tempURL.path)

        #expect(result == .failure(.unsupportedFormat))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' test -only-testing:VideoClipperAppTests/VideoImportServiceTests`
Expected: FAIL — `VideoImportService` does not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
// VideoClipperApp/Sources/Services/VideoImportService.swift
import Foundation
import UniformTypeIdentifiers
import AppKit

enum VideoImportError: Error, Equatable {
    case emptyInput
    case fileNotFound
    case unsupportedFormat
    case notAFileURL
}

struct VideoImportService {
    static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    func resolveVideoURL(
        fromPastedText text: String,
        fileManager: FileManager = .default
    ) -> Result<URL, VideoImportError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.emptyInput)
        }

        let candidateURL: URL
        if let parsed = URL(string: trimmed), let scheme = parsed.scheme {
            guard scheme == "file" else {
                return .failure(.notAFileURL)
            }
            candidateURL = parsed
        } else {
            candidateURL = URL(fileURLWithPath: trimmed)
        }

        guard fileManager.fileExists(atPath: candidateURL.path) else {
            return .failure(.fileNotFound)
        }

        let ext = candidateURL.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            return .failure(.unsupportedFormat)
        }

        return .success(candidateURL)
    }

    @MainActor
    func presentOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' test -only-testing:VideoClipperAppTests/VideoImportServiceTests`
Expected: all 7 tests PASS

- [ ] **Step 5: Commit**

```bash
git add VideoClipperApp/Sources/Services/VideoImportService.swift VideoClipperAppTests/VideoImportServiceTests.swift
git commit -m "feat: add VideoImportService for file-picker and pasted-path resolution"
```

---

### Task 4: `PlayerViewModel` — wraps `AVPlayer`, publishes playback state

**Files:**
- Create: `VideoClipperApp/Sources/ViewModels/PlayerViewModel.swift`
- Test: `VideoClipperAppTests/PlayerViewModelTests.swift`

**Interfaces:**
- Consumes: `TimeFormatter.string(from:)` from Task 2 (used internally for a `formattedCurrentTime` / `formattedDuration` computed property).
- Produces:
  ```swift
  @Observable @MainActor
  final class PlayerViewModel {
      private(set) var player: AVPlayer
      private(set) var isPlaying: Bool
      private(set) var currentTime: Double
      private(set) var duration: Double
      var formattedCurrentTime: String { get }
      var formattedDuration: String { get }

      init(player: AVPlayer = AVPlayer())
      func load(url: URL)
      func togglePlayPause()
      func play()
      func pause()
  }
  ```
  Consumed by Task 5's `PlayerContainerView` (reads `player`) and Task 6's `ContentView` (drives play/pause button, reads `formattedCurrentTime`/`formattedDuration`).

- [ ] **Step 1: Write the failing tests**

```swift
// VideoClipperAppTests/PlayerViewModelTests.swift
import Testing
import AVFoundation
@testable import VideoClipperApp

@MainActor
struct PlayerViewModelTests {

    @Test func initialState_isPausedWithZeroTimes() {
        let viewModel = PlayerViewModel()
        #expect(viewModel.isPlaying == false)
        #expect(viewModel.currentTime == 0)
        #expect(viewModel.duration == 0)
    }

    @Test func togglePlayPause_fromPaused_startsPlaying() {
        let viewModel = PlayerViewModel()
        viewModel.togglePlayPause()
        #expect(viewModel.isPlaying == true)
    }

    @Test func togglePlayPause_fromPlaying_pauses() {
        let viewModel = PlayerViewModel()
        viewModel.play()
        viewModel.togglePlayPause()
        #expect(viewModel.isPlaying == false)
    }

    @Test func pause_setsIsPlayingFalse() {
        let viewModel = PlayerViewModel()
        viewModel.play()
        viewModel.pause()
        #expect(viewModel.isPlaying == false)
    }

    @Test func formattedCurrentTime_reflectsTimeFormatter() {
        let viewModel = PlayerViewModel()
        #expect(viewModel.formattedCurrentTime == TimeFormatter.string(from: 0))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' test -only-testing:VideoClipperAppTests/PlayerViewModelTests`
Expected: FAIL — `PlayerViewModel` does not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
// VideoClipperApp/Sources/ViewModels/PlayerViewModel.swift
import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class PlayerViewModel {
    private(set) var player: AVPlayer
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    private var timeObserverToken: Any?

    var formattedCurrentTime: String { TimeFormatter.string(from: currentTime) }
    var formattedDuration: String { TimeFormatter.string(from: duration) }

    init(player: AVPlayer = AVPlayer()) {
        self.player = player
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        isPlaying = false
        currentTime = 0
        duration = 0
        addTimeObserverIfNeeded()

        Task { [weak self] in
            guard let self else { return }
            let seconds = (try? await item.asset.load(.duration).seconds) ?? 0
            self.duration = seconds.isFinite ? seconds : 0
        }
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    private func addTimeObserverIfNeeded() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' test -only-testing:VideoClipperAppTests/PlayerViewModelTests`
Expected: all 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add VideoClipperApp/Sources/ViewModels/PlayerViewModel.swift VideoClipperAppTests/PlayerViewModelTests.swift
git commit -m "feat: add PlayerViewModel wrapping AVPlayer playback state"
```

---

### Task 5: `PlayerContainerView` — AppKit `AVPlayerView` bridge

**Files:**
- Create: `VideoClipperApp/Sources/Views/PlayerContainerView.swift`

**Interfaces:**
- Consumes: `PlayerViewModel.player` (an `AVPlayer`) from Task 4.
- Produces: `struct PlayerContainerView: NSViewRepresentable { let player: AVPlayer }` — consumed by Task 6's `ContentView`.

No unit test for this task: `NSViewRepresentable` wiring is exercised through the manual UI check in Task 6 (Swift Testing cannot drive AppKit view lifecycle meaningfully here). Skipping automated tests for a pure UIKit/AppKit bridge matches the plan's spec note (5.3/Testing section: "基本 UI 測試" is manual/UI-test-target level, not unit-level).

- [ ] **Step 1: Write the implementation**

```swift
// VideoClipperApp/Sources/Views/PlayerContainerView.swift
import SwiftUI
import AVKit

struct PlayerContainerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add VideoClipperApp/Sources/Views/PlayerContainerView.swift
git commit -m "feat: add PlayerContainerView AVPlayerView bridge"
```

---

### Task 6: Wire `ContentView` — import button, paste-path field, playback UI

**Files:**
- Modify: `VideoClipperApp/Sources/App/ContentView.swift`

**Interfaces:**
- Consumes: `VideoImportService` (Task 3), `PlayerViewModel` (Task 4), `PlayerContainerView` (Task 5).
- Produces: the app's root view, updated in place (no new public interface for later tasks — Phase 2 will add keyboard handling directly to this view or a wrapper).

- [ ] **Step 1: Replace `ContentView` body**

```swift
// VideoClipperApp/Sources/App/ContentView.swift
import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var viewModel = PlayerViewModel()
    @State private var pastedPath: String = ""
    @State private var errorMessage: String?
    private let importService = VideoImportService()

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.duration > 0 || viewModel.player.currentItem != nil {
                PlayerContainerView(player: viewModel.player)
                    .frame(minWidth: 480, minHeight: 270)
            } else {
                emptyState
            }

            HStack {
                Button(viewModel.isPlaying ? "Pause" : "Play") {
                    viewModel.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])

                Text("\(viewModel.formattedCurrentTime) / \(viewModel.formattedDuration)")
                    .monospacedDigit()

                Spacer()

                Button("Choose File…") {
                    chooseFile()
                }
            }

            HStack {
                TextField("Paste file path or file:// URL", text: $pastedPath)
                    .onSubmit { loadPastedPath() }
                Button("Load") { loadPastedPath() }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 380)
    }

    private var emptyState: some View {
        VStack {
            Image(systemName: "video.badge.plus")
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text("Choose a video file or paste a path to begin")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 480, minHeight: 270)
    }

    private func chooseFile() {
        guard let url = importService.presentOpenPanel() else { return }
        errorMessage = nil
        viewModel.load(url: url)
    }

    private func loadPastedPath() {
        switch importService.resolveVideoURL(fromPastedText: pastedPath) {
        case .success(let url):
            errorMessage = nil
            viewModel.load(url: url)
        case .failure(let error):
            errorMessage = message(for: error)
        }
    }

    private func message(for error: VideoImportError) -> String {
        switch error {
        case .emptyInput: return "Please enter a file path."
        case .fileNotFound: return "File not found."
        case .unsupportedFormat: return "Unsupported format (use mp4, mov, or m4v)."
        case .notAFileURL: return "Only local files are supported (no http/https)."
        }
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manual verification**

Launch the app (`mcp__xcode__RunProject` or Xcode Run), then:
1. Click "Choose File…", pick a local `.mp4`/`.mov` file → video frame appears, duration updates from `00:00` to the real length.
2. Click "Play" → button label becomes "Pause", time counter advances.
3. Paste a valid file path into the text field, press Load → video loads.
4. Paste `https://example.com/video.mp4` → error message "Only local files are supported (no http/https)." appears, no crash.
5. Paste an empty string, press Load → error message "Please enter a file path." appears.

- [ ] **Step 4: Run full test suite**

Run: `xcodebuild -project VideoClipperApp.xcodeproj -scheme VideoClipperApp -destination 'platform=macOS' test`
Expected: all tests PASS (TimeFormatter, VideoImportService, PlayerViewModel suites)

- [ ] **Step 5: Commit**

```bash
git add VideoClipperApp/Sources/App/ContentView.swift
git commit -m "feat: wire video import and playback UI into ContentView"
```

---

## Self-Review Notes

- **Spec coverage:** 3.1 (file picker + paste path, local formats only) → Tasks 3, 6. 3.2 (AVPlayer/AVPlayerView, play/pause, time/duration display) → Tasks 4, 5, 6. 5.1 (`PlayerViewModel`) → Task 4. Remote URL support explicitly deferred per spec section 3.1/8 — Task 3 rejects non-file schemes by design, not an oversight.
- **Out of scope for Phase 1** (left for later phases per the spec's own phase breakdown): `ClipSegment`/`TimelineState` models, keyboard navigation, timeline scrubber UI, export — none of Task 1–6 depend on them.
- **Type consistency:** `VideoImportError` cases used identically in Task 3's implementation and Task 6's `message(for:)` switch. `PlayerViewModel.player`/`formattedCurrentTime`/`formattedDuration`/`isPlaying` used identically across Tasks 4, 5, 6.
