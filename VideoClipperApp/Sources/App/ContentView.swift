//
//  ContentView.swift
//  VideoClipperApp
//
//  Created by Lenny Cheng on 2026/8/20.
//

import SwiftUI
import AVFoundation
import AppKit
import os

private let logger = Logger(subsystem: "com.lennycheng.VideoClipperApp", category: "ContentView")

/// Fixed layout heights — kept as named constants (rather than scattered literals) since the
/// video preview and cut-segments list are pinned to constant sizes so marking segments never
/// resizes or squeezes any other element. `windowMinHeight` must stay large enough to fit both
/// of these plus the rest of the chrome (timeline, controls row, spacing, padding).
private enum Layout {
    static let playerHeight: CGFloat = 300
    static let segmentListHeight: CGFloat = 160
    static let windowMinWidth: CGFloat = 560
    static let windowMinHeight: CGFloat = 620
}

struct ContentView: View {
    @State private var viewModel = PlayerViewModel()
    @State private var timeline = TimelineViewModel()
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
            Group {
                if sourceURL != nil {
                    PlayerContainerView(player: viewModel.player)
                } else {
                    emptyState
                }
            }
            .frame(minWidth: 480)
            .frame(height: Layout.playerHeight)

            TimelineView(
                duration: viewModel.duration,
                currentTime: viewModel.currentTime,
                segments: timeline.segments,
                pendingInPoint: timeline.pendingInPoint,
                onSeek: { viewModel.seek(to: $0) }
            )

            // Reserves constant height whether or not a pending in-point is shown, so this text
            // appearing/disappearing never shifts the rest of the layout.
            Text(pendingInPointCaption)
                .font(.caption)
                .foregroundStyle(.green)
                .opacity(timeline.pendingInPoint == nil ? 0 : 1)

            HStack {
                Button(viewModel.isPlaying ? "Pause" : "Play") {
                    viewModel.togglePlayPause()
                }
                .focusable(false)

                Text("\(viewModel.formattedCurrentTime) / \(viewModel.formattedDuration)")
                    .monospacedDigit()

                Spacer()

                Button("Choose File…") {
                    chooseFile()
                }
                .focusable(false)

                Button("Export…") {
                    exportVideo()
                }
                .disabled(isExporting)
                .focusable(false)
            }

            segmentList

            if let exportResultMessage {
                Text(exportResultMessage)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .frame(minWidth: Layout.windowMinWidth, minHeight: Layout.windowMinHeight)
        .onAppear { installKeyEventMonitor() }
        .onDisappear { removeKeyEventMonitor() }
        .onReceive(NotificationCenter.default.publisher(for: .videoClipperOpenFile)) { _ in
            logger.debug("Received videoClipperOpenFile notification")
            chooseFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoClipperExportVideo)) { _ in
            logger.debug("Received videoClipperExportVideo notification")
            exportVideo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoClipperResetAllMarks)) { _ in
            logger.debug("Received videoClipperResetAllMarks notification")
            resetAllMarks()
        }
        .onChange(of: viewModel.currentTime) { _, newTime in
            autoSkipCutSegment(at: newTime)
        }
    }

    private var pendingInPointCaption: String {
        guard let pendingInPoint = timeline.pendingInPoint else {
            return " " // keep a non-empty line so the reserved row doesn't collapse to zero height
        }
        return "In point marked at \(TimeFormatter.string(from: pendingInPoint)) — press O to set the out point"
    }

    private var emptyState: some View {
        VStack {
            Image(systemName: "video.badge.plus")
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text("Choose a video file to begin")
                .foregroundStyle(.secondary)
        }
    }

    // Always occupies the same fixed height, whether or not there are segments to show — an
    // empty List still reserves its layout space, so segments appearing/disappearing never
    // resizes the video preview or shifts any other element.
    private var segmentList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cut segments")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(timeline.segments.isEmpty ? 0 : 1)
            List(timeline.segments) { segment in
                HStack {
                    Text("\(TimeFormatter.string(from: segment.startTime)) – \(TimeFormatter.string(from: segment.endTime))")
                        .font(.caption)
                    Spacer()
                    Button("Delete") {
                        timeline.deleteSegment(id: segment.id)
                    }
                    .font(.caption)
                    .focusable(false)
                }
            }
            .listStyle(.plain)
        }
        .frame(height: Layout.segmentListHeight)
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
        case 126: // up arrow — jump precisely to the previous mark boundary
            if let target = timeline.previousBoundary(before: viewModel.currentTime) {
                viewModel.seek(to: target)
            }
            return true
        case 125: // down arrow — jump precisely to the next mark boundary
            if let target = timeline.nextBoundary(after: viewModel.currentTime) {
                viewModel.seek(to: target)
            }
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
    /// the 10s shift-jump size, applied directly to the exact current playhead time (no rounding —
    /// I/O marks must line up with wherever the playhead actually is). Shift always jumps a fixed 10s.
    /// If a mark boundary falls within the step's range, the playhead stops there instead of
    /// stepping past it — landing on marks feels less abrupt than jumping straight to the raw target.
    private func handleArrowKey(isLeft: Bool, isDown: Bool, isShift: Bool) -> Bool {
        guard isDown else {
            if activeArrowIsLeft == isLeft {
                activeArrowIsLeft = nil
                arrowHoldStreak = 0
            }
            return true
        }

        let magnitude: Double
        if isShift {
            magnitude = 10
        } else {
            if activeArrowIsLeft == isLeft {
                arrowHoldStreak += 1
            } else {
                activeArrowIsLeft = isLeft
                arrowHoldStreak = 0
            }
            magnitude = min(1 + Double(arrowHoldStreak) * 0.5, 10)
        }

        let current = viewModel.currentTime
        let delta = isLeft ? -magnitude : magnitude

        if let snapTarget = timeline.nearestBoundary(from: current, towards: current + delta) {
            viewModel.seek(to: snapTarget)
        } else {
            viewModel.step(by: delta)
        }
        return true
    }

    // MARK: - Actions

    private func autoSkipCutSegment(at time: Double) {
        guard viewModel.isPlaying, let segment = timeline.segment(containing: time) else { return }
        viewModel.seek(to: segment.endTime)
    }

    private func chooseFile() {
        guard let url = importService.presentOpenPanel() else { return }
        exportResultMessage = nil
        loadVideo(at: url)
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

        let segments = timeline.segments
        try? marksPersistenceService.saveSegments(segments, for: sourceURL)

        // Picking the source via NSOpenPanel only grants access to that exact file, not to
        // writing new files in its folder — that fails with a permission error on TCC-protected
        // locations (Desktop/Documents/Downloads). NSSavePanel grants write access to wherever
        // the user confirms, regardless of folder, so use it instead of writing next to the source.
        guard let outputURL = importService.presentSavePanel(suggestedURL: ExportFilenameFormatter.outputURL(for: sourceURL)) else {
            return
        }

        isExporting = true
        exportResultMessage = "Exporting…"
        logger.debug("Starting export to \(outputURL.path) with \(segments.count) cut segment(s)")

        Task {
            do {
                try await exportService.export(sourceURL: sourceURL, cutSegments: segments, outputURL: outputURL)
                logger.debug("Export succeeded: \(outputURL.path)")
                exportResultMessage = "Exported to \(outputURL.lastPathComponent)"
            } catch {
                logger.error("Export failed: \(error.localizedDescription)")
                exportResultMessage = "Export failed: \(error.localizedDescription)"
            }
            isExporting = false
        }
    }
}

#Preview {
    ContentView()
}
