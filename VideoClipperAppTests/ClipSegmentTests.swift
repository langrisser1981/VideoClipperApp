//
//  ClipSegmentTests.swift
//  VideoClipperAppTests
//

import Testing
@testable import VideoClipperApp

struct ClipSegmentTests {

    @Test func init_normalizesReversedStartAndEnd() {
        let segment = ClipSegment(startTime: 10, endTime: 5)
        #expect(segment.startTime == 5)
        #expect(segment.endTime == 10)
    }

    @Test func contains_timeInsideRange_returnsTrue() {
        let segment = ClipSegment(startTime: 5, endTime: 10)
        #expect(segment.contains(7))
    }

    @Test func contains_timeAtEnd_returnsFalse() {
        let segment = ClipSegment(startTime: 5, endTime: 10)
        #expect(!segment.contains(10))
    }

    @Test func contains_timeAtStart_returnsTrue() {
        let segment = ClipSegment(startTime: 5, endTime: 10)
        #expect(segment.contains(5))
    }

    @Test func overlaps_overlappingRanges_returnsTrue() {
        let a = ClipSegment(startTime: 0, endTime: 5)
        let b = ClipSegment(startTime: 3, endTime: 8)
        #expect(a.overlaps(b))
        #expect(b.overlaps(a))
    }

    @Test func overlaps_nonOverlappingRanges_returnsFalse() {
        let a = ClipSegment(startTime: 0, endTime: 5)
        let b = ClipSegment(startTime: 5, endTime: 8)
        #expect(!a.overlaps(b))
    }

    @Test func merged_combinesToOuterBounds() {
        let a = ClipSegment(startTime: 0, endTime: 5)
        let b = ClipSegment(startTime: 3, endTime: 8)
        let merged = a.merged(with: b)
        #expect(merged.startTime == 0)
        #expect(merged.endTime == 8)
    }
}
