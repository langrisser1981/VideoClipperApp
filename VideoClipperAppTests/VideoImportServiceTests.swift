//
//  VideoImportServiceTests.swift
//  VideoClipperAppTests
//

import Testing
import Foundation
@testable import VideoClipperApp

struct VideoImportServiceTests {

    @Test func emptyString_returnsEmptyInputError() {
        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: "")
        #expect(result == .failure(.emptyInput))
    }

    @Test func whitespaceOnlyString_returnsEmptyInputError() {
        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: "   \n  ")
        #expect(result == .failure(.emptyInput))
    }

    @Test func fileURLStringForExistingFile_returnsURL() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).mov")
        FileManager.default.createFile(atPath: tempURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: tempURL.absoluteString)

        #expect(result == .success(tempURL))
    }

    @Test func plainPathStringForExistingFile_returnsURL() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: tempURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: tempURL.path)

        #expect(result == .success(tempURL))
    }

    @Test func nonExistentPath_returnsFileNotFoundError() {
        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: "/tmp/does-not-exist-\(UUID().uuidString).mp4")
        #expect(result == .failure(.fileNotFound))
    }

    @Test func httpURLString_returnsNotAFileURLError() {
        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: "https://example.com/video.mp4")
        #expect(result == .failure(.notAFileURL))
    }

    @Test func unsupportedExtension_returnsUnsupportedFormatError() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: tempURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let service = VideoImportService()
        let result = service.resolveVideoURL(fromPastedText: tempURL.path)

        #expect(result == .failure(.unsupportedFormat))
    }
}
