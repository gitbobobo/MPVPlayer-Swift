//
//  AudioPlayerView.swift
//  MPVPlayerExample
//
//  Created by Zain Wu on 2025/6/28.
//

import SwiftUI
import MPVPlayer

struct AudioPlayerView: View {
    
    @StateObject private var viewModel: PlayerViewModel = PlayerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            MPVPlayerView(player: viewModel.player)
            
            // Audio-specific controls
            playerControls
                .padding()
            
            // Status and metrics
            PlayerStatusView(metrics: viewModel.metrics)
        }
        #if !os(macOS)
        .navigationBarTitle(viewModel.mediaTitle)
         .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            viewModel.load(item: SampleMedia.harpsiCs)
        }
        .onDisappear {
            viewModel.player.stop()
        }
    }
    
    private var playerControls: some View {
        VStack(spacing: 20) {
            
            // Scrubber
            Slider(value: $viewModel.playbackProgress, in: 0...1) { editing in
                if !editing {
                    viewModel.seek(to: viewModel.playbackProgress)
                }
            }
            
            HStack {
                Text(viewModel.currentTimeString)
                Spacer()
                Text(viewModel.durationString)
            }
            
            // Play/Pause Button
            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 50))
            }
        }
    }
}
