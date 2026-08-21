//
//  ContentView.swift
//  VideoClipperApp
//
//  Created by Lenny Cheng on 2026/8/20.
//

import SwiftUI
import AVFoundation

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
    @FocusState private var isKeyboardAreaFocused: Bool
    @FocusState private var focusedControl: FocusableControl?

    private enum FocusableControl: Hashable {
        case chooseFile
        case export
    }

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
                .focused($focusedControl, equals: .chooseFile)

                Button("Export…") {
                    exportVideo()
                }
                .disabled(sourceURL == nil || timeline.segments.isEmpty || isExporting)
                .focused($focusedControl, equals: .export)
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
        .focusable()
        .focusEffectDisabled()
        .focused($isKeyboardAreaFocused)
        .onAppear { isKeyboardAreaFocused = true }
        .onKeyPress(phases: [.down, .repeat, .up]) { handleKeyPress($0) }
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

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow:
            return handleArrowKey(isLeft: true, phase: press.phase, isShift: press.modifiers.contains(.shift))
        case .rightArrow:
            return handleArrowKey(isLeft: false, phase: press.phase, isShift: press.modifiers.contains(.shift))
        default:
            break
        }

        // Everything below only reacts to the initial key-down, not held-key repeats or key-up.
        guard press.phase == .down else { return .ignored }

        if press.modifiers.contains(.command) {
            switch press.characters {
            case "z":
                timeline.undo()
                return .handled
            default:
                return .ignored
            }
        }

        switch press.key {
        case .space:
            viewModel.togglePlayPause()
            return .handled
        case KeyEquivalent("i"):
            timeline.markIn(at: viewModel.currentTime)
            return .handled
        case KeyEquivalent("o"):
            timeline.markOut(at: viewModel.currentTime)
            return .handled
        case .tab:
            focusedControl = (focusedControl == .chooseFile) ? .export : .chooseFile
            return .handled
        case .delete, .deleteForward:
            if timeline.pendingInPoint != nil {
                timeline.cancelPendingInPoint()
                return .handled
            }
            if let segment = timeline.segment(containing: viewModel.currentTime) {
                timeline.deleteSegment(id: segment.id)
                return .handled
            }
            return .ignored
        default:
            return .ignored
        }
    }

    /// Non-shift stepping accelerates the longer the arrow key is held (tracked via repeat events),
    /// ramping from 1s up to the 10s shift-jump size. Shift always jumps a fixed 10s.
    private func handleArrowKey(isLeft: Bool, phase: KeyPress.Phases, isShift: Bool) -> KeyPress.Result {
        if phase == .up {
            if activeArrowIsLeft == isLeft {
                activeArrowIsLeft = nil
                arrowHoldStreak = 0
            }
            return .handled
        }

        if isShift {
            viewModel.step(by: isLeft ? -10 : 10)
            return .handled
        }

        if activeArrowIsLeft == isLeft {
            arrowHoldStreak += 1
        } else {
            activeArrowIsLeft = isLeft
            arrowHoldStreak = 0
        }

        let magnitude = min(1 + Double(arrowHoldStreak) * 0.5, 10)
        viewModel.step(by: isLeft ? -magnitude : magnitude)
        return .handled
    }

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
        guard let sourceURL, !timeline.segments.isEmpty, !isExporting else { return }
        let outputURL = sourceURL
            .deletingPathExtension()
            .appendingPathExtension("clipped")
            .appendingPathExtension("mp4")

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
