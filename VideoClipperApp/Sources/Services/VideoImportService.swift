//
//  VideoImportService.swift
//  VideoClipperApp
//

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
