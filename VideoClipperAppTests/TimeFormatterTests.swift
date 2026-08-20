//
//  TimeFormatterTests.swift
//  VideoClipperAppTests
//

import Testing
@testable import VideoClipperApp

struct TimeFormatterTests {

    @Test func zeroSeconds_formatsAsZeroZero() {
        #expect(TimeFormatter.string(from: 0) == "00:00")
    }

    @Test func underOneMinute_formatsAsMinutesSeconds() {
        #expect(TimeFormatter.string(from: 45) == "00:45")
    }

    @Test func overOneHour_formatsWithHours() {
        #expect(TimeFormatter.string(from: 3725) == "1:02:05")
    }

    @Test func negativeSeconds_clampsToZero() {
        #expect(TimeFormatter.string(from: -5) == "00:00")
    }

    @Test func nanSeconds_clampsToZero() {
        #expect(TimeFormatter.string(from: .nan) == "00:00")
    }
}
