//
//  TimelineViewModel.swift
//  VideoClipperApp
//

import Foundation
import Observation

@Observable
@MainActor
final class TimelineViewModel {
    private(set) var segments: [ClipSegment] = [] {
        didSet { cachedBoundaryTimes = nil }
    }
    private(set) var pendingInPoint: Double? {
        didSet { cachedBoundaryTimes = nil }
    }

    private var undoStack: [[ClipSegment]] = []
    private var cachedBoundaryTimes: [Double]?

    func markIn(at time: Double) {
        pendingInPoint = time
    }

    /// Completes the pending in-point with an out-point at `time`. Does nothing (and keeps the
    /// pending in-point active) if there is no pending in-point, or if `time` is the same as it —
    /// the in- and out-points must be at different positions to form a segment.
    @discardableResult
    func markOut(at time: Double) -> UUID? {
        guard let inPoint = pendingInPoint, inPoint != time else { return nil }
        pendingInPoint = nil
        pushUndoSnapshot()
        let newSegment = ClipSegment(startTime: inPoint, endTime: time)
        addMerging(newSegment)
        return newSegment.id
    }

    /// Discards a pending in-point (marked with `markIn` but not yet completed with `markOut`).
    func cancelPendingInPoint() {
        pendingInPoint = nil
    }

    func deleteSegment(id: UUID) {
        guard segments.contains(where: { $0.id == id }) else { return }
        pushUndoSnapshot()
        segments.removeAll { $0.id == id }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        segments = previous
    }

    func clearAll() {
        pushUndoSnapshot()
        segments = []
        pendingInPoint = nil
    }

    /// Replaces all segments wholesale — used to restore previously-persisted marks for a video.
    func replaceAllSegments(with newSegments: [ClipSegment]) {
        pushUndoSnapshot()
        segments = newSegments.sorted { $0.startTime < $1.startTime }
        pendingInPoint = nil
    }

    func segment(containing time: Double) -> ClipSegment? {
        segments.first { $0.contains(time) }
    }

    /// All marked boundary times (segment start/end points, plus a pending in-point if any),
    /// sorted ascending. Used to jump the playhead precisely onto an existing mark, since arrow-key
    /// stepping is intentionally unrounded and can drift away from whole-second mark positions.
    /// Cached until the next mutation, since arrow-key holds call this on every OS key-repeat tick.
    func boundaryTimes() -> [Double] {
        if let cachedBoundaryTimes { return cachedBoundaryTimes }
        var times = segments.flatMap { [$0.startTime, $0.endTime] }
        if let pendingInPoint {
            times.append(pendingInPoint)
        }
        times.sort()
        cachedBoundaryTimes = times
        return times
    }

    func previousBoundary(before time: Double) -> Double? {
        boundaryTimes().last { $0 < time }
    }

    func nextBoundary(after time: Double) -> Double? {
        boundaryTimes().first { $0 > time }
    }

    /// The closest boundary strictly between `time` and `target` (inclusive of `target`), in the
    /// direction of travel. Used so arrow-key stepping stops at a mark instead of stepping past it,
    /// which feels less abrupt than jumping straight to the raw stepped time.
    func nearestBoundary(from time: Double, towards target: Double) -> Double? {
        if target > time {
            guard let next = nextBoundary(after: time), next <= target else { return nil }
            return next
        } else if target < time {
            guard let previous = previousBoundary(before: time), previous >= target else { return nil }
            return previous
        }
        return nil
    }

    private func pushUndoSnapshot() {
        undoStack.append(segments)
    }

    private func addMerging(_ newSegment: ClipSegment) {
        var merged = newSegment
        var untouched: [ClipSegment] = []
        for existing in segments {
            if merged.overlaps(existing) {
                merged = merged.merged(with: existing)
            } else {
                untouched.append(existing)
            }
        }
        untouched.append(merged)
        segments = untouched.sorted { $0.startTime < $1.startTime }
    }
}
