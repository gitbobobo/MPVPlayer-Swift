//
//  File.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation

/// Describes the playback status of the player.
public enum MPVPlayerTimeStatus: Equatable {
    /// The player is paused.
    case paused
    
    /// The player is actively playing media.
    case playing
    
    /// The player wants to play, but is temporarily waiting for buffer to fill or for other reasons.
    case waitingToPlay
}

public extension Notification.Name {
    /// Posted when the player has finished playing an item.
    static let MPVPlayerDidPlayToEndTime = Notification.Name("MPVPlayerDidPlayToEndTimeNotification")
}
