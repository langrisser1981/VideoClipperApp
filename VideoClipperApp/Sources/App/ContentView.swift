//
//  ContentView.swift
//  VideoClipperApp
//
//  Created by Lenny Cheng on 2026/8/20.
//

import SwiftUI
import AVFoundation
import AppKit

struct ContentView: View {
    @State private var viewModel = PlayerViewModel()
    @State private var timeline = TimelineViewModel()
    @State private var pastedPath: String = ""
    @State private var errorMessage: String?
    @State private var sourceURL: URL?
    @State private var isExporting = false
    @State private var exportResultMessage: String?
    @State private var arrowHoldStreak: Int = 0
    @State private var activeArrowIsLeft: Bool?
    @State private var keyEventMonitor: Any?

    private let importService = VideoImportService()
    private let exportService = ExportService()
    private let marksPersistenceService = MarksPersistenceService()

    var body: some View {
        VStack(spacing: 12) {
            if sourceURL != nil {
                PlayerContainerView(player: viewModel.player)
                    .frame(minWidth: 480, minHeight: 270)
            } else {
                emptyState
            }

            TimelineView(
                duration: viewModel.duration,
                currentTime: viewModel.currentTime,
                segments: timeline.segments,
                pendingInPoint: timeline.pendingInPoint,
                onSeek: { viewModel.seek(to: $0) }
            )

            if let pendingInPoint = timeline.pendingInPoint {
                Text("In point marked at \(TimeFormatter.string(from: pendingInPoint)) — press O to set the out point")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            HStack {
                Button(viewModel.isPlaying ? "Pause" : "Play") {
                    viewModel.togglePlayPause()
                }

                Text("\(viewModel.formattedCurrentTime) / \(viewModel.formattedDuration)")
                    .monospacedDigit()

                Spacer()

                Button("Choose File…") {
                    chooseFile()
                }

                Button("Export…") {
                    exportVideo()
                }
                .disabled(isExporting)
            }

            HStack {
                TextField("Paste file path or file:// URL", text: $pastedPath)
                    .onSubmit { loadPastedPath() }
                Button("Load") { loadPastedPath() }
            }

            segmentList

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if let exportResultMessage {
                Text(exportResultMessage)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 460)
        .onAppear { installKeyEventMonitor() }
        .onDisappear { removeKeyEventMonitor() }
        .onReceive(NotificationCenter.default.publisher(for: .videoClipperOpenFile)) { _ in
            chooseFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoClipperExportVideo)) { _ in
            exportVideo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoClipperResetAllMarks)) { _ in
            resetAllMarks()
        }
        .onChange(of: viewModel.currentTime) { _, newTime in
            autoSkipCutSegment(at: newTime)
        }
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

    private var segmentList: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !timeline.segments.isEmpty {
                Text("Cut segments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                List(timeline.segments) { segment in
                    HStack {
                        Text("\(TimeFormatter.string(from: segment.startTime)) – \(TimeFormatter.string(from: segment.endTime))")
                            .font(.caption)
                        Spacer()
                        Button("Delete") {
                            timeline.deleteSegment(id: segment.id)
                        }
                        .font(.caption)
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 140)
            }
        }
    }

    // MARK: - Keyboard shortcuts

    // Uses an NSEvent local monitor instead of SwiftUI's onKeyPress/@FocusState: onKeyPress only
    // fires while the exact modified view holds SwiftUI's focus, which real-world testing showed
    // gets stolen by any button click, silently disabling every shortcut. A window-level NSEvent
    // monitor intercepts key events regardless of which SwiftUI view currently "has focus".
    private func installKeyEventMonitor() {
        guard keyEventMonitor == nil else { return }
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            // Let an actively-focused text field type normally instead of triggering shortcuts.
            if event.window?.firstResponder is NSTextView {
                return event
            }
            return handleKeyEvent(event) ? nil : event
        }
    }

    private func removeKeyEventMonitor() {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
        keyEventMonitor = nil
    }

    /// Returns true if the event was consumed (should not propagate further).
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let isDown = event.type == .keyDown

        switch event.keyCode {
        case 123: // left arrow
            return handleArrowKey(isLeft: true, isDown: isDown, isShift: event.modifierFlags.contains(.shift))
        case 124: // right arrow
            return handleArrowKey(isLeft: false, isDown: isDown, isShift: event.modifierFlags.contains(.shift))
        default:
            break
        }

        // Everything below only reacts to the initial key-down, not held-key repeats or key-up.
        guard isDown, !event.isARepeat else { return false }

        let modifiers = event.modifierFlags
        let characters = event.charactersIgnoringModifiers?.lowercased()

        if modifiers.contains(.command) {
            if characters == "z" {
                timeline.undo()
                return true
            }
            return false
        }

        switch characters {
        case "i":
            timeline.markIn(at: viewModel.currentTime)
            return true
        case "o":
            timeline.markOut(at: viewModel.currentTime)
            return true
        default:
            break
        }

        switch event.keyCode {
        case 49: // space
            viewModel.togglePlayPause()
            return true
        case 51, 117: // delete / forward-delete
            if timeline.pendingInPoint != nil {
                timeline.cancelPendingInPoint()
                return true
            }
            if let segment = timeline.segment(containing: viewModel.currentTime) {
                timeline.deleteSegment(id: segment.id)
                return true
            }
            return false
        default:
            return false
        }
    }

    /// Non-shift stepping accelerates the longer the arrow key is held, ramping from 1s up to
    /// the 10s shift-jump size. Shift always jumps a fixed 10s.
    private func handleArrowKey(isLeft: Bool, isDown: Bool, isShift: Bool) -> Bool {
        guard isDown else {
            if activeArrowIsLeft == isLeft {
                activeArrowIsLeft = nil
                arrowHoldStreak = 0
            }
            return true
        }

        if isShift {
            viewModel.step(by: isLeft ? -10 : 10)
            return true
        }

        if activeArrowIsLeft == isLeft {
            arrowHoldStreak += 1
        } else {
            activeArrowIsLeft = isLeft
            arrowHoldStreak = 0
        }

        let magnitude = min(1 + Double(arrowHoldStreak) * 0.5, 10)
        viewModel.step(by: isLeft ? -magnitude : magnitude)
        return true
    }

    // MARK: - Actions

    private func autoSkipCutSegment(at time: Double) {
        guard viewModel.isPlaying, let segment = timeline.segment(containing: time) else { return }
        viewModel.seek(to: segment.endTime)
    }

    private func chooseFile() {
        guard let url = importService.presentOpenPanel() else { return }
        errorMessage = nil
        exportResultMessage = nil
        loadVideo(at: url)
    }

    private func loadPastedPath() {
        switch importService.resolveVideoURL(fromPastedText: pastedPath) {
        case .success(let url):
            errorMessage = nil
            exportResultMessage = nil
            loadVideo(at: url)
        case .failure(let error):
            errorMessage = message(for: error)
        }
    }

    private func loadVideo(at url: URL) {
        sourceURL = url
        if let restoredSegments = marksPersistenceService.loadSegments(for: url) {
            timeline.replaceAllSegments(with: restoredSegments)
        } else {
            timeline.clearAll()
        }
        viewModel.load(url: url)
    }

    private func resetAllMarks() {
        timeline.clearAll()
        if let sourceURL {
            marksPersistenceService.deleteMarksFile(for: sourceURL)
        }
    }

    private func exportVideo() {
        guard !isExporting else {
            exportResultMessage = "Export already in progress…"
            return
        }
        guard let sourceURL else {
            exportResultMessage = "Choose or load a video first."
            return
        }
        guard !timeline.segments.isEmpty else {
            exportResultMessage = "No cut segments marked yet — mark one with I / O first."
            return
        }

        let outputURL = ExportFilenameFormatter.outputURL(for: sourceURL)
        let segments = timeline.segments
        try? marksPersistenceService.saveSegments(segments, for: sourceURL)

        isExporting = true
        exportResultMessage = "Exporting…"

        Task {
            do {
                try await exportService.export(sourceURL: sourceURL, cutSegments: segments, outputURL: outputURL)
                exportResultMessage = "Exported to \(outputURL.lastPathComponent)"
            } catch {
                exportResultMessage = "Export failed: \(error.localizedDescription)"
            }
            isExporting = false
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
