//
//  TimeFormatter.swift
//  VideoClipperApp
//

import Foundation

enum TimeFormatter {
    static func string(from seconds: Double) -> String {
        let clamped = seconds.isFinite ? max(0, seconds) : 0
        let totalSeconds = Int(clamped.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
