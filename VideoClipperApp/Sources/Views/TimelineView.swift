//
//  TimelineView.swift
//  VideoClipperApp
//

import SwiftUI

/// Scrubber showing playback progress, marked cut segments (grey), and the playhead.
struct TimelineView: View {
    let duration: Double
    let currentTime: Double
    let segments: [ClipSegment]
    let selectedSegmentID: UUID?
    let pendingInPoint: Double?
    var onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))

                ForEach(segments) { segment in
                    Rectangle()
                        .fill(segment.id == selectedSegmentID ? Color.gray.opacity(0.9) : Color.gray.opacity(0.6))
                        .overlay(
                            segment.id == selectedSegmentID
                                ? RoundedRectangle(cornerRadius: 0).strokeBorder(Color.primary, lineWidth: 1)
                                : nil
                        )
                        .frame(width: width(for: segment, totalWidth: geometry.size.width))
                        .offset(x: xPosition(for: segment.startTime, totalWidth: geometry.size.width))
                }

                if let pendingInPoint {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 2)
                        .offset(x: xPosition(for: pendingInPoint, totalWidth: geometry.size.width))
                }

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
                    .offset(x: xPosition(for: currentTime, totalWidth: geometry.size.width))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard geometry.size.width > 0 else { return }
                        let ratio = min(max(0, value.location.x / geometry.size.width), 1)
                        onSeek(ratio * duration)
                    }
            )
        }
        .frame(height: 32)
    }

    private func xPosition(for time: Double, totalWidth: Double) -> Double {
        guard duration > 0 else { return 0 }
        return (time / duration) * totalWidth
    }

    private func width(for segment: ClipSegment, totalWidth: Double) -> Double {
        guard duration > 0 else { return 0 }
        return ((segment.endTime - segment.startTime) / duration) * totalWidth
    }
}
