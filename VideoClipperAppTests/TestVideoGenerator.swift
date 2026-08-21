//
//  TestVideoGenerator.swift
//  VideoClipperAppTests
//
//  Generates small synthetic .mp4 files (video-only, no audio) by shelling out to ffmpeg's
//  software libx264 encoder. AVAssetWriter + VideoToolbox was tried first but its hardware/software
//  H.264 encoder sessions fail unpredictably in this environment; ffmpeg's software encoder does not
//  go through VideoToolbox and reliably works, while the actual code under test (ExportService, via
//  AVAssetExportSession) still exercises AVFoundation's real re-encode/export pipeline.
//

import Foundation

enum TestVideoGenerator {
    enum GenerationError: Error {
        case ffmpegNotFound
        case ffmpegFailed(Int32)
    }

    private static let candidatePaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]

    static func makeVideo(duration: Double, size: String = "64x64", fps: Int = 10) throws -> URL {
        guard let ffmpegPath = candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw GenerationError.ffmpegNotFound
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-video-\(UUID().uuidString).mp4")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-y",
            "-f", "lavfi", "-i", "testsrc=duration=\(duration):size=\(size):rate=\(fps)",
            "-c:v", "libx264", "-pix_fmt", "yuv420p",
            url.path,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GenerationError.ffmpegFailed(process.terminationStatus)
        }

        return url
    }
}
