//
//  MPVPlaybackMetrics.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation

/// A structure that holds detailed technical information about the currently playing media.
public struct MPVPlaybackMetrics {
    
    // MARK: - Video Properties
    
    /// The name of the current hardware decoder in use (e.g., "videotoolbox").
    public let hardwareDecoder: String?
    
    /// The video format as reported by the decoder.
    public let videoFormat: String?
    
    /// The name of the video codec (e.g., "h264", "hevc").
    public let videoCodec: String?
    
    /// The current video output driver in use (e.g., "libmpv", "gpu").
    public let videoOutputDriver: String?
    
    /// The width of the video in pixels.
    public let width: Int?
    
    /// The height of the video in pixels.
    public let height: Int?
    
    /// The estimated video bitrate in bits per second.
    public let videoBitrate: Double?
    
    /// The estimated frames per second of the video filter output.
    public let outputFPS: Double?
    
    /// The FPS of the container, which may not always be accurate.
    public let containerFPS: Int?
    
    /// The number of frames dropped by the video output.
    public let voFrameDropCount: Int?

    // MARK: - Audio Properties
    
    /// The audio sample format (e.g., "fltp" for floating point planar).
    public let audioFormat: String?
    
    /// The name of the audio codec (e.g., "aac", "opus").
    public let audioCodec: String?
    
    /// The current audio output driver in use (e.g., "coreaudio").
    public let audioOutputDriver: String?
    
    /// The channel layout of the audio (e.g., "stereo").
    public let audioChannels: String?
    
    /// The sample rate of the audio in Hz (e.g., "48000").
    public let audioSampleRate: String?
    
    // MARK: - Caching & Buffering Properties
    
    /// The current cache buffering state as a percentage (0-100).
    public let bufferState: Double?
    
    /// The duration of buffered media in the demuxer cache, in seconds.
    public let cacheDuration: Double?
    
    /// Total number of available tracks (audio, video, subtitle).
    public let trackCount: Int?
    
    /// A boolean indicating if playback is currently paused to wait for the cache.
    public let isPausedForCache: Bool?
    
    /// Internal initializer to create an instance from an MPVClient.
    internal init(from client: MPVClient) {
        self.hardwareDecoder = client.hwDecoder
        self.videoFormat = client.videoFormat
        self.videoCodec = client.videoCodec
        self.videoOutputDriver = client.currentVo
        self.width = Int(client.width)
        self.height = Int(client.height)
        self.videoBitrate = client.videoBitrate
        self.outputFPS = client.outputFps
        self.containerFPS = client.currentContainerFps
        self.voFrameDropCount = client.frameDropCount
        
        self.audioFormat = client.audioFormat
        self.audioCodec = client.audioCodec
        self.audioOutputDriver = client.currentAo
        self.audioChannels = client.audioChannels
        self.audioSampleRate = client.audioSampleRate
        
        self.bufferState = client.bufferingState
        self.cacheDuration = client.cacheDuration
        self.trackCount = client.tracksCount
        self.isPausedForCache = client.pausedForCache
    }
}
