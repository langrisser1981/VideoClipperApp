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
}
