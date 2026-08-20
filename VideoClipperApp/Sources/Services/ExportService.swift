//
//  ExportService.swift
//  VideoClipperApp
//

import Foundation
import AVFoundation

enum ExportError: Error, Equatable {
    case noKeptRanges
    case compositionTrackCreationFailed
    case exportSessionCreationFailed
    case exportFailed(String)
}

struct ExportService {
    func export(
        sourceURL: URL,
        cutSegments: [ClipSegment],
        outputURL: URL,
        fileManager: FileManager = .default
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let durationSeconds = try await asset.load(.duration).seconds

        let keptRanges = ExportRangeCalculator.keptRanges(duration: durationSeconds, cutSegments: cutSegments)
        guard !keptRanges.isEmpty else {
            throw ExportError.noKeptRanges
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.compositionTrackCreationFailed
        }
        let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first
        let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first

        // Only add a composition audio track when the source actually has one —
        // an empty, unused audio track makes AVAssetExportSession fail with "Operation Stopped".
        let compositionAudioTrack = sourceAudioTrack != nil
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil

        var insertTime = CMTime.zero
        for range in keptRanges {
            let timeRange = CMTimeRange(
                start: CMTime(seconds: range.lowerBound, preferredTimescale: 600),
                end: CMTime(seconds: range.upperBound, preferredTimescale: 600)
            )
            if let sourceVideoTrack {
                try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)
            }
            if let sourceAudioTrack, let compositionAudioTrack {
                try compositionAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
            }
            insertTime = insertTime + timeRange.duration
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.exportSessionCreationFailed
        }

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        do {
            try await exportSession.export(to: outputURL, as: .mp4)
        } catch {
            throw ExportError.exportFailed(error.localizedDescription)
        }
    }
}
