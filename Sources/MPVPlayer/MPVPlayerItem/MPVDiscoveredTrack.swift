//
//  MPVDiscoveredTrack.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation

/// Represents a track (audio or subtitle) discovered by the mpv core from the media container itself.
public struct MPVDiscoveredTrack: Hashable, Identifiable {
    
    public enum TrackType: String {
        case audio
        case subtitle
        case unknown
    }
    
    /// The track ID assigned by mpv. This is used to select the track.
    public let id: String
    
    /// The type of the track.
    public let type: TrackType
    
    /// The language code of the track, if available.
    public let language: String?
    
    /// The title of the track, if available.
    public let title: String?
    
    /// A user-facing label for display in a UI.
    public var displayTitle: String {
        if let title, !title.isEmpty {
            return title
        }
        if let language, !language.isEmpty {
            return language.capitalized
        }
        return "Track \(id)"
    }
}
