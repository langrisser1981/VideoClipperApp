//
//  TimelineViewModelTests.swift
//  VideoClipperAppTests
//

import Testing
@testable import VideoClipperApp

@MainActor
struct TimelineViewModelTests {

    @Test func markIn_setsPendingInPoint() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 5)
        #expect(timeline.pendingInPoint == 5)
        #expect(timeline.segments.isEmpty)
    }

    @Test func markOut_afterMarkIn_createsSegment() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 5)
        timeline.markOut(at: 10)
        #expect(timeline.segments.count == 1)
        #expect(timeline.segments[0].startTime == 5)
        #expect(timeline.segments[0].endTime == 10)
        #expect(timeline.pendingInPoint == nil)
    }

    @Test func markOut_withoutPendingInPoint_doesNothing() {
        let timeline = TimelineViewModel()
        timeline.markOut(at: 10)
        #expect(timeline.segments.isEmpty)
    }

    @Test func markIn_calledAgainWithPendingInPoint_replacesIt() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 5)
        timeline.markIn(at: 8)
        #expect(timeline.pendingInPoint == 8)
    }

    @Test func markOut_atSamePositionAsInPoint_doesNothingAndKeepsPending() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 5)
        let result = timeline.markOut(at: 5)
        #expect(result == nil)
        #expect(timeline.segments.isEmpty)
        #expect(timeline.pendingInPoint == 5)
    }

    @Test func markOut_beforeInPoint_normalizesOrder() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 10)
        timeline.markOut(at: 5)
        #expect(timeline.segments[0].startTime == 5)
        #expect(timeline.segments[0].endTime == 10)
    }

    @Test func markOut_overlappingExistingSegment_mergesThem() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 0)
        timeline.markOut(at: 5)
        timeline.markIn(at: 3)
        timeline.markOut(at: 8)
        #expect(timeline.segments.count == 1)
        #expect(timeline.segments[0].startTime == 0)
        #expect(timeline.segments[0].endTime == 8)
    }

    @Test func deleteSegment_removesMatchingSegment() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 0)
        timeline.markOut(at: 5)
        let id = timeline.segments[0].id
        timeline.deleteSegment(id: id)
        #expect(timeline.segments.isEmpty)
    }

    @Test func undo_afterAddingSegment_removesIt() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 0)
        timeline.markOut(at: 5)
        timeline.undo()
        #expect(timeline.segments.isEmpty)
    }

    @Test func undo_afterDeletingSegment_restoresIt() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 0)
        timeline.markOut(at: 5)
        let id = timeline.segments[0].id
        timeline.deleteSegment(id: id)
        timeline.undo()
        #expect(timeline.segments.count == 1)
        #expect(timeline.segments[0].id == id)
    }

    @Test func clearAll_removesAllSegmentsAndPending() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 0)
        timeline.markOut(at: 5)
        timeline.markIn(at: 8)
        timeline.clearAll()
        #expect(timeline.segments.isEmpty)
        #expect(timeline.pendingInPoint == nil)
    }

    @Test func segmentContaining_timeInsideCutSegment_returnsSegment() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 5)
        timeline.markOut(at: 10)
        #expect(timeline.segment(containing: 7)?.startTime == 5)
    }

    @Test func segmentContaining_timeOutsideAnySegment_returnsNil() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 5)
        timeline.markOut(at: 10)
        #expect(timeline.segment(containing: 12) == nil)
    }

    @Test func markOut_returnsIdOfCreatedSegment() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 5)
        let id = timeline.markOut(at: 10)
        #expect(id == timeline.segments[0].id)
    }

    @Test func markOut_returnsIdOfMergedSegmentAfterOverlap() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 0)
        timeline.markOut(at: 5)
        timeline.markIn(at: 3)
        let secondId = timeline.markOut(at: 8)
        #expect(timeline.segments.count == 1)
        #expect(secondId == timeline.segments[0].id)
    }

    @Test func replaceAllSegments_setsSegmentsSortedAndClearsPending() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 50)
        let restored = [
            ClipSegment(startTime: 20, endTime: 30),
            ClipSegment(startTime: 0, endTime: 5),
        ]
        timeline.replaceAllSegments(with: restored)
        #expect(timeline.segments.map(\.startTime) == [0, 20])
        #expect(timeline.pendingInPoint == nil)
    }

    @Test func cancelPendingInPoint_clearsPendingWithoutCreatingSegment() {
        let timeline = TimelineViewModel()
        timeline.markIn(at: 5)
        timeline.cancelPendingInPoint()
        #expect(timeline.pendingInPoint == nil)
        #expect(timeline.segments.isEmpty)
    }
}
