//
//  ClipSegment.swift
//  VideoClipperApp
//

import Foundation

/// A time range (in seconds) marked to be cut out of the source video.
struct ClipSegment: Identifiable, Equatable, Hashable {
    let id: UUID
    var startTime: Double
    var endTime: Double

    init(id: UUID = UUID(), startTime: Double, endTime: Double) {
        self.id = id
        self.startTime = min(startTime, endTime)
        self.endTime = max(startTime, endTime)
    }

    func contains(_ time: Double) -> Bool {
        time >= startTime && time < endTime
    }

    func overlaps(_ other: ClipSegment) -> Bool {
        startTime < other.endTime && other.startTime < endTime
    }

    /// Merges this segment with an overlapping (or touching) segment into a single covering segment.
    func merged(with other: ClipSegment) -> ClipSegment {
        ClipSegment(
            id: id,
            startTime: min(startTime, other.startTime),
            endTime: max(endTime, other.endTime)
        )
    }
}
