//
//  FiUIMPVPlayerViewle.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//
import SwiftUI
#if canImport(UIKit)
public typealias PlatformViewControllerRepresentable = UIViewControllerRepresentable
#elseif canImport(AppKit)
public typealias PlatformViewControllerRepresentable = NSViewControllerRepresentable
#endif

public struct MPVPlayerView: PlatformViewControllerRepresentable {
    
    #if canImport(AppKit)
    public typealias NSViewControllerType = MPVPlayerViewController
    
    #elseif canImport(UIKit)
    public typealias UIViewControllerType = MPVPlayerViewController
    #endif
    
    private var player: MPVPlayer
    
    public init(player: MPVPlayer) {
        self.player = player
    }
    
    #if canImport(UIKit)
    public func makeUIViewController(context: Context) -> MPVPlayerViewController {
        return MPVPlayerViewController(player: player)
    }
    
    public func updateUIViewController(_ uiViewController: MPVPlayerViewController, context: Context) {
        
    }
    #elseif canImport(AppKit)
    public func makeNSViewController(context: Context) -> MPVPlayerViewController {
        return MPVPlayerViewController(player: player)
    }
    
    public func updateNSViewController(_ nsViewController: MPVPlayerViewController, context: Context) {
        
    }
    #endif
}

