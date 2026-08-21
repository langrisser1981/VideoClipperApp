//
//  ExportFilenameFormatterTests.swift
//  VideoClipperAppTests
//

import Testing
import Foundation
@testable import VideoClipperApp

struct ExportFilenameFormatterTests {

    @Test func outputURL_staysInSameDirectoryAsSource() {
        let source = URL(fileURLWithPath: "/Users/me/Movies/vacation.mov")
        let result = ExportFilenameFormatter.outputURL(for: source, timestamp: Date())
        #expect(result.deletingLastPathComponent().path == source.deletingLastPathComponent().path)
    }

    @Test func outputURL_usesMp4Extension() {
        let source = URL(fileURLWithPath: "/tmp/clip.mov")
        let result = ExportFilenameFormatter.outputURL(for: source, timestamp: Date())
        #expect(result.pathExtension == "mp4")
    }

    @Test func outputURL_matchesNameUnderscoreTimestampPattern() {
        let source = URL(fileURLWithPath: "/Users/me/Movies/vacation.mov")
        let result = ExportFilenameFormatter.outputURL(for: source, timestamp: Date())
        let name = result.deletingPathExtension().lastPathComponent
        #expect(name.hasPrefix("vacation_"))
        let stamp = String(name.dropFirst("vacation_".count))
        #expect(stamp.count == 14)
        #expect(stamp.allSatisfy { $0.isNumber })
    }

    @Test func outputURL_differentTimestamps_produceDifferentNames() {
        let source = URL(fileURLWithPath: "/tmp/clip.mp4")
        let a = ExportFilenameFormatter.outputURL(for: source, timestamp: Date(timeIntervalSince1970: 0))
        let b = ExportFilenameFormatter.outputURL(for: source, timestamp: Date(timeIntervalSince1970: 100_000))
        #expect(a != b)
    }
}
