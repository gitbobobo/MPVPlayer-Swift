//
//  File.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation

/// An object that represents the assets to be played by an MPVPlayer.
/// This is analogous to AVPlayerItem.
public struct MPVPlayerItem {
    
    /// The primary type of the media asset.
    public enum AssetType {
        case video
        case audio
    }
    
    /// The primary asset URL (can be video or audio).
    public let url: URL
    
    /// The type of the primary asset.
    public let assetType: AssetType
    
    /// A list of optional audio tracks to be made available for playback.
    public let audioAssets: [MPVAudioAsset]
    
    /// A list of optional subtitle tracks to be made available for playback.
    public let subtitles: [MPVSubtitle]
    
    public init(videoURL: URL, audioAssets: [MPVAudioAsset] = [], subtitles: [MPVSubtitle] = []) {
        self.url = videoURL
        self.assetType = .video
        self.audioAssets = audioAssets
        self.subtitles = subtitles
    }
    
    /// Initializes a player item for an audio-only asset.
    public init(audioURL: URL) {
        self.url = audioURL
        self.assetType = .audio
        self.audioAssets = []
        self.subtitles = [] 
    }
}
