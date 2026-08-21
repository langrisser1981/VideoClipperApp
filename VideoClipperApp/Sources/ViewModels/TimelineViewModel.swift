//
//  TimelineViewModel.swift
//  VideoClipperApp
//

import Foundation
import Observation

@Observable
@MainActor
final class TimelineViewModel {
    private(set) var segments: [ClipSegment] = []
    private(set) var pendingInPoint: Double?

    private var undoStack: [[ClipSegment]] = []

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

    func segment(containing time: Double) -> ClipSegment? {
        segments.first { $0.contains(time) }
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
