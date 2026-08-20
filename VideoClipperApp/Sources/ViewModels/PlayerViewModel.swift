//
//  PlayerViewModel.swift
//  VideoClipperApp
//

import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class PlayerViewModel {
    private(set) var player: AVPlayer
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0

    private var timeObserverToken: Any?

    var formattedCurrentTime: String { TimeFormatter.string(from: currentTime) }
    var formattedDuration: String { TimeFormatter.string(from: duration) }

    init(player: AVPlayer = AVPlayer(), duration: Double = 0) {
        self.player = player
        self.duration = duration
    }

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        isPlaying = false
        currentTime = 0
        duration = 0
        addTimeObserverIfNeeded()

        Task { [weak self] in
            guard let self else { return }
            let seconds = (try? await item.asset.load(.duration).seconds) ?? 0
            self.duration = seconds.isFinite ? seconds : 0
        }
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to time: Double) {
        let clamped = min(max(0, time), duration)
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func step(by delta: Double) {
        seek(to: currentTime + delta)
    }

    private func addTimeObserverIfNeeded() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }
}
