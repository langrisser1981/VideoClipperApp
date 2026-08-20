//
//  ExportRangeCalculatorTests.swift
//  VideoClipperAppTests
//

import Testing
@testable import VideoClipperApp

struct ExportRangeCalculatorTests {

    @Test func noSegments_returnsFullDurationRange() {
        let ranges = ExportRangeCalculator.keptRanges(duration: 100, cutSegments: [])
        #expect(ranges == [0..<100])
    }

    @Test func singleSegmentInMiddle_returnsTwoRanges() {
        let segment = ClipSegment(startTime: 30, endTime: 50)
        let ranges = ExportRangeCalculator.keptRanges(duration: 100, cutSegments: [segment])
        #expect(ranges == [0..<30, 50..<100])
    }

    @Test func segmentCoveringStart_returnsSingleTrailingRange() {
        let segment = ClipSegment(startTime: 0, endTime: 20)
        let ranges = ExportRangeCalculator.keptRanges(duration: 100, cutSegments: [segment])
        #expect(ranges == [20..<100])
    }

    @Test func segmentCoveringEnd_returnsSingleLeadingRange() {
        let segment = ClipSegment(startTime: 80, endTime: 100)
        let ranges = ExportRangeCalculator.keptRanges(duration: 100, cutSegments: [segment])
        #expect(ranges == [0..<80])
    }

    @Test func segmentCoveringEntireDuration_returnsEmptyRanges() {
        let segment = ClipSegment(startTime: 0, endTime: 100)
        let ranges = ExportRangeCalculator.keptRanges(duration: 100, cutSegments: [segment])
        #expect(ranges.isEmpty)
    }

    @Test func multipleUnorderedSegments_returnsSortedComplementRanges() {
        let segments = [
            ClipSegment(startTime: 60, endTime: 70),
            ClipSegment(startTime: 10, endTime: 20),
        ]
        let ranges = ExportRangeCalculator.keptRanges(duration: 100, cutSegments: segments)
        #expect(ranges == [0..<10, 20..<60, 70..<100])
    }

    @Test func adjacentSegments_mergeGapAway() {
        let segments = [
            ClipSegment(startTime: 10, endTime: 20),
            ClipSegment(startTime: 20, endTime: 30),
        ]
        let ranges = ExportRangeCalculator.keptRanges(duration: 100, cutSegments: segments)
        #expect(ranges == [0..<10, 30..<100])
    }
}
