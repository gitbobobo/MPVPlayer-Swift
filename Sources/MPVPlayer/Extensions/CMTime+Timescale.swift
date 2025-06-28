//
//  CMTime+Timescale.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation
import CoreMedia

public extension CMTime {
    static let defaultTimescale: CMTimeScale = 1_000_000

    static func secondsInDefaultTimescale(_ seconds: TimeInterval) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: CMTime.defaultTimescale)
    }
}
