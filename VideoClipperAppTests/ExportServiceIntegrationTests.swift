//
//  ExportServiceIntegrationTests.swift
//  VideoClipperAppTests
//
//  End-to-end tests that generate a real (tiny, synthetic) video, run it through the actual
//  AVMutableComposition/AVAssetExportSession pipeline, and verify a real output file is produced —
//  not just that the pure range-calculation logic is correct.
//

import Testing
import Foundation
import AVFoundation
@testable import VideoClipperApp

struct ExportServiceIntegrationTests {

    @Test func export_withCutSegment_producesShorterPlayableOutputFile() async throws {
        let sourceURL = try TestVideoGenerator.makeVideo(duration: 4)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let sourceDuration = try await AVURLAsset(url: sourceURL).load(.duration).seconds

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-test-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let cut = ClipSegment(startTime: 1, endTime: 2)
        let service = ExportService()
        try await service.export(sourceURL: sourceURL, cutSegments: [cut], outputURL: outputURL)

        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        let outputDuration = try await AVURLAsset(url: outputURL).load(.duration).seconds
        let expectedDuration = sourceDuration - (cut.endTime - cut.startTime)
        #expect(abs(outputDuration - expectedDuration) < 0.5)
    }

    @Test func export_withNoCutSegments_outputMatchesSourceDuration() async throws {
        let sourceURL = try TestVideoGenerator.makeVideo(duration: 2)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let sourceDuration = try await AVURLAsset(url: sourceURL).load(.duration).seconds

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-test-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let service = ExportService()
        try await service.export(sourceURL: sourceURL, cutSegments: [], outputURL: outputURL)

        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        let outputDuration = try await AVURLAsset(url: outputURL).load(.duration).seconds
        #expect(abs(outputDuration - sourceDuration) < 0.5)
    }

    @Test func export_withCutSegmentCoveringEntireVideo_throwsNoKeptRanges() async throws {
        let sourceURL = try TestVideoGenerator.makeVideo(duration: 2)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let sourceDuration = try await AVURLAsset(url: sourceURL).load(.duration).seconds
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-test-\(UUID().uuidString).mp4")

        let service = ExportService()
        let fullCut = ClipSegment(startTime: 0, endTime: sourceDuration)

        await #expect(throws: ExportError.self) {
            try await service.export(sourceURL: sourceURL, cutSegments: [fullCut], outputURL: outputURL)
        }
        #expect(!FileManager.default.fileExists(atPath: outputURL.path))
    }
}
