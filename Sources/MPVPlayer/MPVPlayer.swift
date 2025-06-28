// The Swift Programming Language
// https://docs.swift.org/swift-book
import AVFAudio
import CoreMedia
import Foundation
import Libmpv
import MediaPlayer
import Repeat
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public class MPVPlayer: ObservableObject, @unchecked Sendable {
    // MARK: - Public Properties
    
    /// The player's current media item.
    @Published public private(set) var currentItem: MPVPlayerItem?
    
    /// A list of tracks discovered by mpv from the media container.
    @Published public private(set) var discoveredTracks: [MPVDiscoveredTrack] = []
    
    /// The ID of the currently active audio track. Corresponds to an ID from `discoveredTracks` or `currentItem.audioAssets`.
    @Published public var currentAudioTrackID: String?
    
    /// The ID of the currently active subtitle track. Corresponds to an ID from `discoveredTracks` or `currentItem.subtitles`.
    @Published public var currentSubtitleID: String?
    
    /// The current playback time of the player.
    public var currentTime: CMTime {
        return client?.currentTime ?? .zero
    }
    
    /// The duration of the currently loaded media.
    public var duration: CMTime {
        return client?.duration ?? .zero
    }
    
    /// The current playback rate. Default is 1.0 (normal speed).
    @Published public var rate: Float {
        didSet {
            client?.setDoubleAsync("speed", Double(rate))
        }
    }
    
    /// Provides access to detailed technical information about the current media.
    /// This property returns `nil` if no media is currently playing.
    /// The information is fetched on-demand each time this property is accessed.
    public var metrics: MPVPlaybackMetrics? {
        guard let client = self.client, currentItem != nil else {
            return nil
        }
        
        return MPVPlaybackMetrics(from: client)
    }
    
    /// A Boolean value indicating whether the player is currently playing.
    @Published public private(set) var isPlaying: Bool = false
    
    /// The current playback status of the player.
    @Published public private(set) var timeControlStatus: MPVPlayerTimeStatus = .paused
    
    /// The natural size of the video, required by MPVClient for layout calculations.
    @Published public var playerSize: CGSize = .zero
    
    /// A Boolean value that indicates whether the player has finished playing the media.
    public var isFinished: Bool {
        return client?.eofReached ?? false
    }
    
    /// The aspect ratio of the video.
    public var aspectRatio: Double {
        client?.aspectRatio ?? 16.0 / 9.0
    }
    
    // MARK: - Internal Properties
    #if DEBUG
    private let logger = PackageLogger.shared
    #endif
    internal var client: MPVClient?
    private var timeObservers = [UUID: (MPVPlayer) -> Void]()
    private var timeObserverTimer: Repeater?
    private var onFileLoaded: (() -> Void)?
    private var isPausedForCache: Bool = false
    
    // MARK: - Initialization
    public init() {
        self.rate = 1.0
        self.client = MPVClient()
        self.client?.player = self
        self.client?.create()
    }
    
    deinit {
        stop()
        stopPeriodicTimer()
        DispatchQueue.global(qos: .background).async { [client] in
            client?.destroy()
        }
    }
    
    // MARK: - Playback Control
    
    /// Begins playback of the current item.
    public func play() {
        client?.play()
    }
    
    /// Pauses playback of the current item.
    public func pause() {
        client?.pause()
    }
    
    /// Toggles the playback state.
    public func togglePlay() {
        client?.togglePlay()
    }
    
    /// Stops playback and unloads the current media.
    public func stop() {
        client?.stop()
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPausedForCache = false
            self.updateTimeControlStatus()
        }
    }
    
    @MainActor
    private func updateTimeControlStatus() {
        if isPlaying && isPausedForCache {
            self.timeControlStatus = .waitingToPlay
        } else if isPlaying {
            self.timeControlStatus = .playing
        } else {
            self.timeControlStatus = .paused
        }
    }
    
    /// Replaces the current item with a new `MPVPlayerItem`.
    /// - Parameter item: The `MPVPlayerItem` to play.
    public func replaceCurrentItem(with item: MPVPlayerItem, autoPlaying: Bool = true) {

        self.stop()
        self.currentItem = item
        self.discoveredTracks = []
        self.currentAudioTrackID = nil
        self.currentSubtitleID = nil

        client?.loadFile(item.url) { [weak self] _ in
            #if DEBUG
            self?.logger.info("Main video file loading initiated.")
            #endif
        }
        
        onFileLoaded = { [weak self] in
            guard let self = self, let client = self.client else { return }
            let tracks = client.fetchTrackList()
            Task { @MainActor in
                self.discoveredTracks = tracks
                if let firstAudio = tracks.first(where: { $0.type == .audio }) {
                    self.selectAudioTrack(withID: firstAudio.id)
                }
                if let firstSub = tracks.first(where: { $0.type == .subtitle }) {
                    self.selectSubtitle(withID: firstSub.id)
                }
                self.play()
            }
        }
    }
    
    /// Selects an audio track by its ID.
    /// This method intelligently handles both embedded and sideloaded audio tracks.
    /// - Parameters:
    ///   - id: The ID of the track to select.
    ///   - completion: An optional closure called with `true` on success or `false` on failure.
    @MainActor
    public func selectAudioTrack(withID id: String, completion: ((Bool) -> Void)? = nil) {
        guard self.currentItem?.assetType == .video else {
            #if DEBUG
            logger.warning("Cannot select audio track for an audio-only asset.")
            #endif
            completion?(false)
            return
        }
        guard let client, let currentItem else {
            completion?(false)
            return
        }
        if discoveredTracks.contains(where: { $0.id == id && $0.type == .audio }) {
            client.setString("aid", id)
            self.currentAudioTrackID = id
            #if DEBUG
            logger.info("Switched to embedded audio track ID: \(id)")
            #endif
            completion?(true)
            return
        }
        if let audioAsset = currentItem.audioAssets.first(where: { $0.id == id }) {
            #if DEBUG
            logger.info("Switching to sideloaded audio track '\(audioAsset.label)' by reloading.")
            #endif
            let preservedTime = self.currentTime

            let currentSubURL = self.currentSubtitleURL()
            
            onFileLoaded = { [weak self] in
                guard let self = self else { return }
                let tracks = self.client?.fetchTrackList() ?? []
                Task { @MainActor in
                    self.discoveredTracks = tracks
                    self.currentAudioTrackID = audioAsset.id
                    completion?(true)
                    self.play()
                }
            }
            
            client.loadFile(
                currentItem.url,
                audio: audioAsset.url,
                sub: currentSubURL,
                time: preservedTime
            )
            return
        }
        
        #if DEBUG
        logger.warning("Audio track with ID '\(id)' not found.")
        #endif
        completion?(false)
    }
    
    /// Selects a subtitle track by its ID, or disables subtitles.
    /// - Parameter id: The ID of the track to select. Use "no" or `nil` to disable subtitles.
    @MainActor
    public func selectSubtitle(withID id: String?) {
        guard self.currentItem?.assetType == .video else {
            #if DEBUG
            logger.warning("Cannot select subtitle for an audio-only asset.")
            #endif
            return
        }
        guard let client else { return }
        
        guard let subtitleID = id, subtitleID != "no" else {
            Task {
                await client.removeSubs()
                self.currentSubtitleID = nil
                #if DEBUG
                logger.info("All subtitles removed.")
                #endif
            }
            return
        }
        if discoveredTracks.contains(where: { $0.id == subtitleID && $0.type == .subtitle }) {
            client.setString("sid", subtitleID)
            self.currentSubtitleID = subtitleID
            #if DEBUG
            logger.info("Switched to embedded subtitle track ID: \(subtitleID)")
            #endif
            return
        }
        
        if let subtitle = currentItem?.subtitles.first(where: { $0.id == subtitleID }) {
            #if DEBUG
            logger.info("Replacing subtitles with sideloaded file: \(subtitle.label)")
            #endif
            Task {
                await client.removeSubs()
                await client.addSubTrack(subtitle.url)

                self.currentSubtitleID = subtitle.id

                let tracks = client.fetchTrackList()
                Task { @MainActor in
                     self.discoveredTracks = tracks
                }
            }
            return
        }
        #if DEBUG
        logger.warning("Subtitle track with ID '\(subtitleID)' not found.")
        #endif
    }
    
    /// Moves the playback cursor to a specified time.
    ///
    /// - Parameters:
    ///   - time: The time to seek to.
    ///   - completionHandler: A closure to be called when the seek operation is complete.
    public func seek(to time: CMTime, completionHandler: ((Bool) -> Void)? = nil) {
        client?.seek(to: time, completionHandler: completionHandler)
    }
    
    /// - Parameters:
    ///   - time: Relative time based on the current playback time
    ///   - completionHandler: A closure to be called when the seek operation is complete.
    public func seek(relative time: CMTime, completionHandler: ((Bool) -> Void)? = nil) {
        client?.seek(relative: time, completionHandler: completionHandler)
    }
    
    // MARK: - Observers
    
    public func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue? = nil, using block: @escaping (MPVPlayer) -> Void) -> Any {
        let id = UUID()
        let q = queue ?? .main
        
        timeObservers[id] = { (player: MPVPlayer) in
            q.async {
                block(player)
            }
        }
        
        if timeObserverTimer == nil {
            startPeriodicTimer(interval: interval)
        }
        
        return id as Any
    }
    
    public func removeTimeObserver(_ observer: Any) {
        guard let id = observer as? UUID else { return }
        timeObservers.removeValue(forKey: id)
        
        if timeObservers.isEmpty {
            stopPeriodicTimer()
        }
    }
    
    private func startPeriodicTimer(interval: CMTime) {
        let timeInterval = interval.seconds
        timeObserverTimer = Repeater(interval: .seconds(timeInterval), mode: .infinite) { [weak self] _ in
            guard let self = self else { return }
            for (_, block) in self.timeObservers {
                block(self)
            }
        }
        timeObserverTimer?.start()
    }
    
    private func stopPeriodicTimer() {
        timeObserverTimer?.pause()
        timeObserverTimer = nil
    }
    
    // MARK: - UI Interaction
    @MainActor
    func setSize(width: Double, height: Double) {
        // Set the player's own size property first
        self.playerSize = CGSize(width: width, height: height)
        // Then, tell the client to update the rendering surface
        client?.setSize(width, height)
    }
    
    #if canImport(AppKit)
    @MainActor
    func setView(_ view: NSView?) {
        if let videoLayer = view?.layer as? VideoLayer {
            self.client?.attachView(videoLayer)
        }
    }
    #elseif canImport(UIKit)
    @MainActor
    func setView(_ view: UIView?) {
        if let glView = view as? MPVOGLView {
            self.client?.attachView(glView)
        }
    }
    #endif
    
    // MARK: - Event Handling from MPVClient
    internal func handle(event: UnsafePointer<mpv_event>!) {
        #if DEBUG
        logger.debug("Received event: \(String(cString: mpv_event_name(event.pointee.event_id)))")
        #endif
        switch event.pointee.event_id {
        case MPV_EVENT_SHUTDOWN:
            #if DEBUG
            logger.info("MPV shutdown event received.")
            #endif
            client?.mpv = nil
            
        case MPV_EVENT_LOG_MESSAGE:
            #if DEBUG
            let logmsg = UnsafeMutablePointer<mpv_event_log_message>(OpaquePointer(event.pointee.data))
            let text = String(cString: (logmsg!.pointee.text)!)
            logger.info("\(text)")
            #else
            break
            #endif
        case MPV_EVENT_FILE_LOADED:
            #if DEBUG
            logger.info("File loaded successfully.")
            #endif
            DispatchQueue.main.async { [weak self] in
                self?.onFileLoaded?()
                self?.onFileLoaded = nil
            }
            
        case MPV_EVENT_PLAYBACK_RESTART:
            #if DEBUG
            logger.info("Playback restarting.")
            #endif
            DispatchQueue.main.async {
                self.isPlaying = true
            }
            
        case MPV_EVENT_PROPERTY_CHANGE:
            let prop = UnsafePointer<mpv_event_property>(OpaquePointer(event.pointee.data))?.pointee
            if let property = prop {
                let propertyName = String(cString: property.name)
                handlePropertyChange(propertyName, property)
            }
            
        case MPV_EVENT_END_FILE:
            handleEndOfFile()
            
        default:
            break
        }
    }
    
    private func handlePropertyChange(_ name: String, _ property: mpv_event_property) {
         switch name {
         case "pause":
             if let paused = UnsafePointer<Bool>(OpaquePointer(property.data))?.pointee {
                 DispatchQueue.main.async { [weak self] in
                     self?.isPlaying = !paused
                     self?.updateTimeControlStatus()
                 }
             }
         case "core-idle":
             if let idle = UnsafePointer<Bool>(OpaquePointer(property.data))?.pointee, !idle {
                 DispatchQueue.main.async { [weak self] in
                     self?.isPlaying = true
                     self?.updateTimeControlStatus()
                 }
             }
         case "paused-for-cache":
             if let waiting = UnsafePointer<Bool>(OpaquePointer(property.data))?.pointee {
                 DispatchQueue.main.async { [weak self] in
                     self?.isPausedForCache = waiting
                     self?.updateTimeControlStatus()
                 }
             }
         default:
             break
         }
     }
    
    private func handleEndOfFile() {
        #if DEBUG
        logger.info("End of file reached.")
        #endif
        Task { @MainActor in
            self.isPlaying = false
            self.updateTimeControlStatus()
            NotificationCenter.default.post(
                name: .MPVPlayerDidPlayToEndTime,
                object: self
            )
        }
    }
    
    // Find the URL of the current subtitle track
    private func currentSubtitleURL() -> URL? {
        guard let currentSubtitleID else { return nil }
        return currentItem?.subtitles.first(where: { $0.id == currentSubtitleID })?.url
    }
     
}
