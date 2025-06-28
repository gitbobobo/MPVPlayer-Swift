//
//  PlayerStatusView.swift
//  MPVPlayerExample
//
//  Created by Zain Wu on 2025/6/28.
//

import SwiftUI
import MPVPlayer

/// A reusable SwiftUI view to display detailed playback metrics.
struct PlayerStatusView: View {
    let metrics: MPVPlaybackMetrics?
    
    var body: some View {
        List {
            Section(header: Text("Playback Status")) {
                if let metrics = metrics {
                    row("Video Codec", metrics.videoCodec)
                    row("Audio Codec", metrics.audioCodec)
                    row("Resolution", resolutionString)
                    row("Hardware Decoder", metrics.hardwareDecoder)
                    row("Output FPS", metrics.outputFPS.map { String(format: "%.2f", $0) })
                    row("Dropped Frames", metrics.voFrameDropCount.map(String.init))
                    row("Buffer State", metrics.bufferState.map { String(format: "%.1f%%", $0) })
                    row("Cache Duration", metrics.cacheDuration.map { String(format: "%.2fs", $0) })
                } else {
                    Text("Information unavailable.")
                        .foregroundColor(.secondary)
                }
            }
        }
        // .listStyle(InsetGroupedListStyle())
    }
    
    private var resolutionString: String? {
        guard let w = metrics?.width, let h = metrics?.height else { return nil }
        return "\(w)x\(h)"
    }
    
    private func row(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ?? "N/A")
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
