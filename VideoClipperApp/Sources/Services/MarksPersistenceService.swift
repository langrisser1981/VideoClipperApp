//
//  MarksPersistenceService.swift
//  VideoClipperApp
//

import Foundation

private struct StoredClipSegment: Codable {
    let startTime: Double
    let endTime: Double
}

/// Persists a video's cut-segment marks to a sidecar JSON file next to the source video,
/// so re-opening the same video restores the previous marks instead of starting blank.
struct MarksPersistenceService {
    func marksFileURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("clipmarks.json")
    }

    func loadSegments(for videoURL: URL, fileManager: FileManager = .default) -> [ClipSegment]? {
        let url = marksFileURL(for: videoURL)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([StoredClipSegment].self, from: data) else {
            return nil
        }
        return stored.map { ClipSegment(startTime: $0.startTime, endTime: $0.endTime) }
    }

    func saveSegments(_ segments: [ClipSegment], for videoURL: URL) throws {
        let url = marksFileURL(for: videoURL)
        let stored = segments.map { StoredClipSegment(startTime: $0.startTime, endTime: $0.endTime) }
        let data = try JSONEncoder().encode(stored)
        try data.write(to: url, options: .atomic)
    }

    func deleteMarksFile(for videoURL: URL, fileManager: FileManager = .default) {
        let url = marksFileURL(for: videoURL)
        try? fileManager.removeItem(at: url)
    }
}
