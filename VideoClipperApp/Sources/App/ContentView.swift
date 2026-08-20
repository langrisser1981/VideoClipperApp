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
    @State private var selectedSegmentID: UUID?
    @State private var sourceURL: URL?
    @State private var isExporting = false
    @State private var exportResultMessage: String?
    @FocusState private var isKeyboardAreaFocused: Bool

    private let importService = VideoImportService()
    private let exportService = ExportService()

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
                onSeek: { viewModel.seek(to: $0) }
            )

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
                .disabled(sourceURL == nil || timeline.segments.isEmpty || isExporting)
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
        .onKeyPress { handleKeyPress($0) }
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
                ForEach(timeline.segments) { segment in
                    HStack {
                        Text("\(TimeFormatter.string(from: segment.startTime)) – \(TimeFormatter.string(from: segment.endTime))")
                            .font(.caption)
                            .foregroundStyle(selectedSegmentID == segment.id ? Color.primary : Color.secondary)
                        Spacer()
                        Button("Delete") {
                            timeline.deleteSegment(id: segment.id)
                            if selectedSegmentID == segment.id { selectedSegmentID = nil }
                        }
                        .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedSegmentID = segment.id }
                }
            }
        }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) {
            switch press.characters {
            case "z":
                timeline.undo()
                return .handled
            case "e":
                exportVideo()
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
        case .leftArrow:
            viewModel.step(by: press.modifiers.contains(.shift) ? -5 : -1)
            return .handled
        case .rightArrow:
            viewModel.step(by: press.modifiers.contains(.shift) ? 5 : 1)
            return .handled
        case .delete, .deleteForward:
            if let id = selectedSegmentID {
                timeline.deleteSegment(id: id)
                selectedSegmentID = nil
                return .handled
            }
            return .ignored
        default:
            return .ignored
        }
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
        timeline.clearAll()
        selectedSegmentID = nil
        viewModel.load(url: url)
    }

    private func exportVideo() {
        guard let sourceURL, !timeline.segments.isEmpty, !isExporting else { return }
        let outputURL = sourceURL
            .deletingPathExtension()
            .appendingPathExtension("clipped")
            .appendingPathExtension("mp4")

        isExporting = true
        exportResultMessage = "Exporting…"
        let segments = timeline.segments

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
