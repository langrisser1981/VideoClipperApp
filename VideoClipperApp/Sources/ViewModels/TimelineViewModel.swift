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

    func markOut(at time: Double) {
        guard let inPoint = pendingInPoint else { return }
        pendingInPoint = nil
        pushUndoSnapshot()
        addMerging(ClipSegment(startTime: inPoint, endTime: time))
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
