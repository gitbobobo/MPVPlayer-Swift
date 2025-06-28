//
//  MPVSubtitle.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation

/// Represents a single subtitle track that can be sideloaded.
public struct MPVSubtitle: Hashable, Identifiable {
    /// A unique identifier for the subtitle track.
    public var id: String
    
    /// The display name for the subtitle, e.g., "English".
    public let label: String
    
    /// The language code, e.g., "en" or "eng".
    public let code: String
    
    /// The URL of the subtitle file (e.g., .srt, .vtt, .ass).
    public let url: URL
    
    public init(id: String = UUID().uuidString, label: String, code: String, url: URL) {
        self.id = id
        self.label = label
        self.code = code
        self.url = url
    }
    
    /// A descriptive string for UI purposes.
    public var description: String {
        "\(label) (\(code))"
    }
}
