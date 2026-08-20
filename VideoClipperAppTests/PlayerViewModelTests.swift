//
//  PlayerViewModelTests.swift
//  VideoClipperAppTests
//

import Testing
import AVFoundation
@testable import VideoClipperApp

@MainActor
struct PlayerViewModelTests {

    @Test func initialState_isPausedWithZeroTimes() {
        let viewModel = PlayerViewModel()
        #expect(viewModel.isPlaying == false)
        #expect(viewModel.currentTime == 0)
        #expect(viewModel.duration == 0)
    }

    @Test func togglePlayPause_fromPaused_startsPlaying() {
        let viewModel = PlayerViewModel()
        viewModel.togglePlayPause()
        #expect(viewModel.isPlaying == true)
    }

    @Test func togglePlayPause_fromPlaying_pauses() {
        let viewModel = PlayerViewModel()
        viewModel.play()
        viewModel.togglePlayPause()
        #expect(viewModel.isPlaying == false)
    }

    @Test func pause_setsIsPlayingFalse() {
        let viewModel = PlayerViewModel()
        viewModel.play()
        viewModel.pause()
        #expect(viewModel.isPlaying == false)
    }

    @Test func formattedCurrentTime_reflectsTimeFormatter() {
        let viewModel = PlayerViewModel()
        #expect(viewModel.formattedCurrentTime == TimeFormatter.string(from: 0))
    }

    @Test func seek_withinRange_setsExactTime() {
        let viewModel = PlayerViewModel(duration: 100)
        viewModel.seek(to: 42)
        #expect(viewModel.currentTime == 42)
    }

    @Test func seek_negativeTime_clampsToZero() {
        let viewModel = PlayerViewModel(duration: 100)
        viewModel.seek(to: -5)
        #expect(viewModel.currentTime == 0)
    }

    @Test func seek_beyondDuration_clampsToDuration() {
        let viewModel = PlayerViewModel(duration: 100)
        viewModel.seek(to: 150)
        #expect(viewModel.currentTime == 100)
    }

    @Test func step_byPositiveDelta_increasesCurrentTime() {
        let viewModel = PlayerViewModel(duration: 100)
        viewModel.seek(to: 10)
        viewModel.step(by: 5)
        #expect(viewModel.currentTime == 15)
    }

    @Test func step_byNegativeDelta_decreasesCurrentTime() {
        let viewModel = PlayerViewModel(duration: 100)
        viewModel.seek(to: 10)
        viewModel.step(by: -3)
        #expect(viewModel.currentTime == 7)
    }

    @Test func step_clampsAtZero() {
        let viewModel = PlayerViewModel(duration: 100)
        viewModel.seek(to: 2)
        viewModel.step(by: -10)
        #expect(viewModel.currentTime == 0)
    }

    @Test func step_clampsAtDuration() {
        let viewModel = PlayerViewModel(duration: 10)
        viewModel.seek(to: 8)
        viewModel.step(by: 5)
        #expect(viewModel.currentTime == 10)
    }
}
