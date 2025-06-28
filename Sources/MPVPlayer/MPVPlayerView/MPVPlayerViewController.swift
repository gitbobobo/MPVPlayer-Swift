//
//  MPVPlayerViewController.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import Repeat

public final class MPVPlayerViewController: PlatformViewController {
    // MARK: - Properties
    
    private let player: MPVPlayer
    
    // The view that renders mpv's output
    private let playerView: PlatformView
    
    // The view that is shown for audio-only media
    private var audioPlaceholderView: PlatformView!
    
    private var refreshRateTimer: Repeater?
    private let refreshRateUpdateInterval: TimeInterval = 0.5 // 0.5 seconds
    /// Set to `true` to allow the player to attempt to match the display's refresh rate
    /// to the video's content FPS. This can result in smoother playback for certain content
    /// (e.g., 24fps video on a 120Hz ProMotion display).
    /// Defaults to `false`.
    public var syncsDisplayRefreshRateToVideo: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(player: MPVPlayer) {
        self.player = player
        
        #if canImport(UIKit)
        self.playerView = MPVOGLView(frame: .zero)
        #elseif canImport(AppKit)
        let view = NSView()
        view.wantsLayer = true
        let videoLayer = VideoLayer()
        view.layer = videoLayer
        self.playerView = view
        #endif
        
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    #if canImport(UIKit)
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startRefreshRateUpdates()
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRefreshRateUpdates()
    }
    #elseif canImport(AppKit)
    override public func viewDidAppear() {
        super.viewDidAppear()
        startRefreshRateUpdates()
    }
    override public func viewWillDisappear() {
        super.viewWillDisappear()
        stopRefreshRateUpdates()
    }
    #endif
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        #if canImport(UIKit)
        view.backgroundColor = .black
        #endif
        
        setupAudioPlaceholderView()
        setupPlayerView()
        player.client?.InitializeGLContext()
        player.setView(self.playerView)
        
        #if canImport(AppKit)
        if let videoLayer = self.playerView.layer as? VideoLayer {
            videoLayer.client = player.client
        }
        #endif
        
        setupBindings()
    }
    
    #if canImport(AppKit)
    override public func viewDidLayout() {
        super.viewDidLayout()
        player.setSize(width: view.bounds.width, height: view.bounds.height)
    }
    #elseif canImport(UIKit)
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        player.setSize(width: view.bounds.width, height: view.bounds.height)
    }
    #endif

    // MARK: - Private Methods
    
    private func setupPlayerView() {
        playerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerView)
        
        PlatformLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupAudioPlaceholderView() {
        audioPlaceholderView = PlatformView()
        audioPlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        #if canImport(UIKit)
        audioPlaceholderView.backgroundColor = .black
        #endif
        
        let symbolName = "music.note"
        let imageView: PlatformView
        
        #if canImport(UIKit)
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .thin)
        let image = PlatformImage(systemName: symbolName, withConfiguration: config)
        let uiImageView = UIImageView(image: image)
        uiImageView.tintColor = .lightGray
        imageView = uiImageView
        #elseif canImport(AppKit)
        let nsImageView: NSImageView
        
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 50, weight: .thin)
            let image = PlatformImage(systemSymbolName: symbolName, accessibilityDescription: "Audio playback")?
                .withSymbolConfiguration(config) ?? PlatformImage()
            nsImageView = NSImageView(image: image)
            if #available(macOS 12.0, *)  {
                nsImageView.symbolConfiguration = .init(paletteColors: [.lightGray])
            } else {
                nsImageView.contentTintColor = .lightGray
            }
        } else {
            /// macOS 10.15 and below, SF Symbols cannot be used directly
            nsImageView = NSImageView()
        }
        imageView = nsImageView
        #endif
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        audioPlaceholderView.addSubview(imageView)
        view.addSubview(audioPlaceholderView)
        
        PlatformLayoutConstraint.activate([
            audioPlaceholderView.topAnchor.constraint(equalTo: view.topAnchor),
            audioPlaceholderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            audioPlaceholderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            audioPlaceholderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            imageView.centerXAnchor.constraint(equalTo: audioPlaceholderView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: audioPlaceholderView.centerYAnchor)
        ])
    }
    
    private func setupBindings() {
        player.$currentItem
            .receive(on: DispatchQueue.main)
            .sink { [weak self] item in
                self?.updateView(for: item)
            }
            .store(in: &cancellables)
    }
    
     private func updateView(for item: MPVPlayerItem?) {
         guard let item = item else {
             playerView.isHidden = true
             audioPlaceholderView.isHidden = false
             return
         }
         
         switch item.assetType {
         case .video:
             playerView.isHidden = false
             audioPlaceholderView.isHidden = true
         case .audio:
             playerView.isHidden = true
             audioPlaceholderView.isHidden = false
         }
     }
    
    /// Starts the periodic timer to check and update the display refresh rate.
    private func startRefreshRateUpdates() {
        guard syncsDisplayRefreshRateToVideo,
              refreshRateTimer == nil else { return }
        let refreshRateUpdateInterval = self.refreshRateUpdateInterval
        refreshRateTimer = .init(interval: .seconds(refreshRateUpdateInterval), mode: .infinite, queue: .main) { [weak self] _ in
            self?.checkAndUpdateRefreshRate()
        }
        refreshRateTimer?.start()
    }
    
    private func stopRefreshRateUpdates() {
        refreshRateTimer?.pause()
        refreshRateTimer = nil
    }
    
    /// Checks if the display's refresh rate should be adjusted to match the video content's FPS.
    private func checkAndUpdateRefreshRate() {
        guard let client = player.client, player.timeControlStatus == .playing else { return }
        
        let screenRefreshRate = client.getScreenRefreshRate()

        let contentFps = client.currentContainerFps

        if contentFps > 0 && screenRefreshRate != contentFps {
            client.updateRefreshRate(to: contentFps)
            client.currentRefreshRate = contentFps
            notifyViewToUpdateDisplayLink(with: contentFps)
        } else if client.currentRefreshRate != screenRefreshRate {
            client.updateRefreshRate(to: screenRefreshRate)
            client.currentRefreshRate = screenRefreshRate
            notifyViewToUpdateDisplayLink(with: screenRefreshRate)
        }
    }
    
    /// Notifies the underlying CADisplayLink on UIKit-based platforms to update its preferred frame rate.
    private func notifyViewToUpdateDisplayLink(with fps: Int) {
        #if canImport(UIKit)
        NotificationCenter.default.post(name: .updateDisplayLinkFrameRate, object: nil, userInfo: ["refreshRate": fps])
        #endif
    }
}
