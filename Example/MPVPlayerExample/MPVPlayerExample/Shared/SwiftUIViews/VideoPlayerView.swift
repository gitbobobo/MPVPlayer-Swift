//
//  VideoPlayerView.swift
//  MPVPlayerExample
//
//  Created by Zain Wu on 2025/6/28.
//

import SwiftUI
import MPVPlayer

struct VideoPlayerView: View {
    
    @StateObject private var viewModel: PlayerViewModel =  PlayerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            MPVPlayerView(player: viewModel.player)
            
            // Playback controls
            playerControls
                .padding()
                .background(Color.secondary)
            
            // A list for displaying metrics and track selection
            PlayerStatusView(metrics: viewModel.metrics)
                .frame(height: 300)
        }
        #if !os(macOS)
        .navigationBarTitle(viewModel.mediaTitle)
        // .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            viewModel.load(item: SampleMedia.bigBuckBunny)
        }
        .onDisappear {
            viewModel.player.stop()
        }
    }
    
    private var playerControls: some View {
        VStack {
            // Time display and scrubber
            HStack {
                Text(viewModel.currentTimeString)
                Slider(value: $viewModel.playbackProgress, in: 0...1) { editing in
                    if !editing {
                        viewModel.seek(to: viewModel.playbackProgress)
                    }
                }
                Text(viewModel.durationString)
            }
            
            // Play/Pause button
            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
            }
            .padding(.top)
            
            // Track selection
            HStack {
                Picker("Audio", selection: $viewModel.selectedAudioTrackID) {
                    ForEach(viewModel.discoveredAudioTracks) { track in
                        Text(track.displayTitle).tag(track.id as String?)
                    }
                }
                //.pickerStyle(.menu)
                
                Picker("Subtitles", selection: $viewModel.selectedSubtitleTrackID) {
                    Text("None").tag(nil as String?)
                    ForEach(viewModel.discoveredSubtitleTracks) { track in
                        Text(track.displayTitle).tag(track.id as String?)
                    }
                }
                //.pickerStyle(.menu)
            }
            .disabled(viewModel.timeControlStatus == .paused)
        }
    }
}
