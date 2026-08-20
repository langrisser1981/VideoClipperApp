//
//  ExportRangeCalculator.swift
//  VideoClipperApp
//

import Foundation

/// Computes the time ranges to keep (i.e. the complement of the cut segments) over [0, duration).
enum ExportRangeCalculator {
    static func keptRanges(duration: Double, cutSegments: [ClipSegment]) -> [Range<Double>] {
        guard duration > 0 else { return [] }

        let merged = mergeSegments(cutSegments)
        var result: [Range<Double>] = []
        var cursor = 0.0

        for segment in merged {
            let start = min(max(0, segment.startTime), duration)
            let end = min(max(0, segment.endTime), duration)
            if start > cursor {
                result.append(cursor..<start)
            }
            cursor = max(cursor, end)
        }

        if cursor < duration {
            result.append(cursor..<duration)
        }

        return result
    }

    private static func mergeSegments(_ segments: [ClipSegment]) -> [ClipSegment] {
        let sorted = segments.sorted { $0.startTime < $1.startTime }
        var merged: [ClipSegment] = []
        for segment in sorted {
            if let last = merged.last, segment.startTime <= last.endTime {
                merged[merged.count - 1] = last.merged(with: segment)
            } else {
                merged.append(segment)
            }
        }
        return merged
    }
}
