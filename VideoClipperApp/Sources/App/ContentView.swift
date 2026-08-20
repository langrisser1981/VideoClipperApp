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
