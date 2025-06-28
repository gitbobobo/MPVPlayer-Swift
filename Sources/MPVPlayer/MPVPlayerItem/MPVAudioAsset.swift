//
//  MPVAudioAsset.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation

/// Represents a single audio track that can be sideloaded as a secondary audio source.
public struct MPVAudioAsset: Hashable, Identifiable {
    /// A unique identifier for the audio track.
    public var id: String
    
    /// The display name for the audio, e.g., "Director's Commentary".
    public let label: String
    
    /// The language code, e.g., "en".
    public let code: String
    
    /// The URL of the audio file.
    public let url: URL
    
    public init(id: String = UUID().uuidString, label: String, code: String, url: URL) {
        self.id = id
        self.label = label
        self.code = code
        self.url = url
    }
}
