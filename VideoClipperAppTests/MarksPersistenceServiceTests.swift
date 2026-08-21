//
//  MarksPersistenceServiceTests.swift
//  VideoClipperAppTests
//

import Testing
import Foundation
@testable import VideoClipperApp

struct MarksPersistenceServiceTests {

    @Test func marksFileURL_derivesFromVideoURL() {
        let service = MarksPersistenceService()
        let videoURL = URL(fileURLWithPath: "/tmp/movie.mp4")
        #expect(service.marksFileURL(for: videoURL).lastPathComponent == "movie.clipmarks.json")
    }

    @Test func loadSegments_whenNoFileExists_returnsNil() {
        let service = MarksPersistenceService()
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).mp4")
        #expect(service.loadSegments(for: videoURL) == nil)
    }

    @Test func saveThenLoadSegments_roundTripsValues() throws {
        let service = MarksPersistenceService()
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).mp4")
        defer { service.deleteMarksFile(for: videoURL) }

        let segments = [
            ClipSegment(startTime: 5, endTime: 10),
            ClipSegment(startTime: 20, endTime: 25),
        ]
        try service.saveSegments(segments, for: videoURL)

        let loaded = try #require(service.loadSegments(for: videoURL))
        #expect(loaded.count == 2)
        #expect(loaded[0].startTime == 5)
        #expect(loaded[0].endTime == 10)
        #expect(loaded[1].startTime == 20)
        #expect(loaded[1].endTime == 25)
    }

    @Test func deleteMarksFile_removesPersistedFile() throws {
        let service = MarksPersistenceService()
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).mp4")
        try service.saveSegments([ClipSegment(startTime: 1, endTime: 2)], for: videoURL)

        service.deleteMarksFile(for: videoURL)

        #expect(service.loadSegments(for: videoURL) == nil)
    }

    @Test func saveSegments_withEmptyArray_writesEmptyFile() throws {
        let service = MarksPersistenceService()
        let videoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).mp4")
        defer { service.deleteMarksFile(for: videoURL) }

        try service.saveSegments([], for: videoURL)

        let loaded = try #require(service.loadSegments(for: videoURL))
        #expect(loaded.isEmpty)
    }
}
