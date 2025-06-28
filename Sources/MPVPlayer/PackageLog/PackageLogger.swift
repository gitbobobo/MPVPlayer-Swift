//
//  PackageLogger.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//
#if DEBUG
import Foundation
import os.log

final class PackageLogger: Sendable {
    static let shared = PackageLogger()
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "MPVPlayer", category: "PackageLogger")
    
    private init() { }
    
    func debug(_ message: String, function: String = #function) {
        os_log("[DEBUG][%{public}@] %{public}@", log: log, type: .debug, function, message)
    }

    func info(_ message: String, function: String = #function) {
        os_log("[INFO][%{public}@] %{public}@", log: log, type: .info, function, message)
    }

    func warning(_ message: String, function: String = #function) {
        os_log("[WARNING][%{public}@] %{public}@", log: log, type: .default, function, message)
    }

    func error(_ message: String, function: String = #function) {
        os_log("[ERROR][%{public}@] %{public}@", log: log, type: .error, function, message)
    }
    
}
#endif
