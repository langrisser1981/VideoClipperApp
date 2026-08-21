//
//  ExportFilenameFormatter.swift
//  VideoClipperApp
//

import Foundation

/// Builds the export output URL as `<original name>_<yyyyMMddHHmmss>.mp4` next to the source video.
enum ExportFilenameFormatter {
    private static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHHmmss"
        df.timeZone = .current
        return df
    }()

    static func outputURL(for sourceURL: URL, timestamp: Date = Date()) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let stamp = formatter.string(from: timestamp)
        return sourceURL.deletingLastPathComponent()
            .appendingPathComponent("\(baseName)_\(stamp)")
            .appendingPathExtension("mp4")
    }
}
