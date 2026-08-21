//
//  MarksPersistenceService.swift
//  VideoClipperApp
//

import Foundation
import CryptoKit

private struct StoredClipSegment: Codable {
    let startTime: Double
    let endTime: Double
}

/// Persists a video's cut-segment marks to a JSON file in Application Support, keyed by the
/// video's absolute path, so re-opening the same video restores the previous marks.
///
/// Marks are NOT stored next to the source video: picking a file via NSOpenPanel only grants
/// this (unsandboxed) app access to that exact file, not to writing new files in its folder —
/// writing next to the source reliably fails with a permission error for files under TCC-protected
/// locations like Desktop/Documents/Downloads. Application Support is always writable.
struct MarksPersistenceService {
    func marksFileURL(for videoURL: URL, fileManager: FileManager = .default) -> URL {
        marksDirectory(fileManager: fileManager)
            .appendingPathComponent("\(key(for: videoURL)).clipmarks.json")
    }

    func loadSegments(for videoURL: URL, fileManager: FileManager = .default) -> [ClipSegment]? {
        let url = marksFileURL(for: videoURL, fileManager: fileManager)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([StoredClipSegment].self, from: data) else {
            return nil
        }
        return stored.map { ClipSegment(startTime: $0.startTime, endTime: $0.endTime) }
    }

    func saveSegments(_ segments: [ClipSegment], for videoURL: URL, fileManager: FileManager = .default) throws {
        let url = marksFileURL(for: videoURL, fileManager: fileManager)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let stored = segments.map { StoredClipSegment(startTime: $0.startTime, endTime: $0.endTime) }
        let data = try JSONEncoder().encode(stored)
        try data.write(to: url, options: .atomic)
    }

    func deleteMarksFile(for videoURL: URL, fileManager: FileManager = .default) {
        let url = marksFileURL(for: videoURL, fileManager: fileManager)
        try? fileManager.removeItem(at: url)
    }

    private func marksDirectory(fileManager: FileManager) -> URL {
        let appSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("VideoClipperApp/Marks", isDirectory: true)
    }

    /// A stable, collision-resistant, filesystem-safe identifier derived from the video's absolute path.
    private func key(for videoURL: URL) -> String {
        let path = videoURL.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
