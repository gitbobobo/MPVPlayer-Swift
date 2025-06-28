//
//  PlayerViewModel.swift
//  MPVPlayerExample
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation
import Combine
import AVFoundation
import MPVPlayer

class PlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties for UI Binding
    
    /// The player instance managed by this view model.
    let player: MPVPlayer = MPVPlayer()
    
    /// The title of the currently loaded media item.
    @Published var mediaTitle: String = "No Media Loaded"
    
    /// The current playback status (e.g., playing, paused, waiting).
    @Published var timeControlStatus: MPVPlayerTimeStatus = .paused
    
    /// A formatted string for the current playback time (e.g., "01:23").
    @Published var currentTimeString: String = "00:00"
    
    /// A formatted string for the total duration of the media (e.g., "10:00").
    @Published var durationString: String = "00:00"
    
    /// The current playback progress, from 0.0 to 1.0, for use with a Slider.
    @Published var playbackProgress: Double = 0.0
    
    /// A snapshot of detailed technical metrics about the playback.
    @Published var metrics: MPVPlaybackMetrics?

    /// A list of discovered audio tracks from the media file.
    @Published var discoveredAudioTracks: [MPVDiscoveredTrack] = []
    
    /// A list of discovered subtitle tracks from the media file.
    @Published var discoveredSubtitleTracks: [MPVDiscoveredTrack] = []

    /// The ID of the currently selected audio track.
    @Published var selectedAudioTrackID: String? {
        didSet {
            guard let id = selectedAudioTrackID else { return }
            Task { @MainActor [weak self] in
                self?.player.selectAudioTrack(withID: id)
            }
        }
    }
    
    /// The ID of the currently selected subtitle track.
    @Published var selectedSubtitleTrackID: String? {
        didSet {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.player.selectSubtitle(withID: selectedSubtitleTrackID ?? "no")
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?

    // MARK: - Lifecycle
    
    init() {
        setupBindings()
    }
    
    deinit {
        // Clean up resources when the view model is deallocated.
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        player.stop()
        print("PlayerViewModel deinitialized.")
    }

    // MARK: - Public Control Methods
    
    /// Loads a streamable item into the player.
    /// - Parameter item: The `StreamableItem` to load.
    func load(item: StreamableItem) {
        self.mediaTitle = item.title
        
        let playerItem: MPVPlayerItem
        switch item.type {
        case .video:
            playerItem = MPVPlayerItem(videoURL: item.url)
        case .audio:
            playerItem = MPVPlayerItem(audioURL: item.url)
        }
        player.replaceCurrentItem(with: playerItem)
    }
    
    /// Toggles the playback state between playing and paused.
    func togglePlayback() {
        player.togglePlay()
    }
    
    /// Seeks to a new progress position.
    /// - Parameter progress: The new progress, from 0.0 to 1.0.
    func seek(to progress: Double) {
        let duration = player.duration.seconds
        guard duration.isFinite, duration > 0 else { return }
        let time = CMTime(seconds: progress * duration, preferredTimescale: 600)
        player.seek(to: time)
    }

    // MARK: - Private Binding Setup
    
    func setupBindings() {
        // Bind to the player's timeControlStatus
        player.$timeControlStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.timeControlStatus, on: self)
            .store(in: &cancellables)

        // Bind to the player's discovered tracks
        player.$discoveredTracks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                self?.discoveredAudioTracks = tracks.filter { $0.type == .audio }
                self?.discoveredSubtitleTracks = tracks.filter { $0.type == .subtitle }
            }
            .store(in: &cancellables)
        
        // Use a periodic time observer to update time-related properties.
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1.0, preferredTimescale: 600), queue: .main) { [weak self] player in
            guard let self = self else { return }
            
            let currentTime = player.currentTime.seconds
            let duration = player.duration.seconds
            
            self.currentTimeString = self.formatTime(currentTime)
            self.durationString = self.formatTime(duration)
            
            if duration.isFinite && duration > 0 {
                self.playbackProgress = currentTime / duration
            } else {
                self.playbackProgress = 0
            }
            
            // Periodically refresh the technical metrics
            self.metrics = player.metrics
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "--:--" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
