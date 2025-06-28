//
//  MPVClient.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation
import CoreMedia
import Libmpv
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class MPVClient {
    #if DEBUG
    private var logger = PackageLogger.shared
    #endif
    private var needsDrawingCooldown = false
    private var needsDrawingWorkItem: DispatchWorkItem?
    
    var mpv: OpaquePointer!
    var mpvGL: OpaquePointer!
    var queue: DispatchQueue!
    
    #if canImport(AppKit)
    var layer: VideoLayer!
    var link: CVDisplayLink!
    #elseif canImport(UIKit)
    var glView: MPVOGLView!
    #endif
    weak var player: MPVPlayer!
    
    var seeking = false
    var currentRefreshRate = 60
    
    private var initializedGLContext: Bool = false

    func create() {
        mpv = mpv_create()
        if mpv == nil {
            #if DEBUG
            logger.error("failed creating context\n")
            #endif
            exit(1)
        }
        checkError(mpv_request_log_messages(mpv, "no"))
        
        #if os(macOS)
        let imkOp = MPVOptions.anyOption("input-media-keys", value: "yes")
        imkOp.setupDefault(with: mpv)
        #endif
        
        MPVOptions.allCases.forEach {
            $0.setupDefault(with: mpv)
        }
        
        // Determine number of threads based on system core count
        let numberOfCores = ProcessInfo.processInfo.processorCount
        let threads = numberOfCores * 2
        
        #if DEBUG
        logger.info("Number of CPU cores: \(numberOfCores)")
        #endif
        let vltOp = MPVOptions.anyOption("vd-lavc-threads", value: "\(threads)")
        vltOp.setupDefault(with: mpv)
        
        #if canImport(AppKit)
        let ytdlOp = MPVOptions.anyOption("ytdl", value: "no")
        ytdlOp.setupDefault(with: mpv)
        #endif
        
        checkError(mpv_initialize(mpv))
        
        queue = DispatchQueue(label: "mpv", qos: .userInteractive, attributes: [.concurrent])
        
        mpv_set_wakeup_callback(mpv, wakeUp, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        mpv_observe_property(mpv, 0, "pause", MPV_FORMAT_FLAG)
        mpv_observe_property(mpv, 0, "core-idle", MPV_FORMAT_FLAG)
        mpv_observe_property(mpv, 0, "paused-for-cache", MPV_FORMAT_FLAG)
    }
    
    #if canImport(UIKit)
    @MainActor
    func attachView(_ view: MPVOGLView) {
        guard let mpvGL = self.mpvGL else {
            print("mpvGL 为 nil")
            return
        }
        let gpuOp = MPVOptions.gpuAPI
        gpuOp.setupDefault(with: mpv, value: gpuOp.default)
        self.glView = view
        self.glView.mpvGL = UnsafeMutableRawPointer(mpvGL)
        
        mpv_render_context_set_update_callback(
            mpvGL,
            glUpdate(_:),
            UnsafeMutableRawPointer(Unmanaged.passUnretained(view).toOpaque())
        )
    }
    #elseif canImport(AppKit)
    func attachView(_ layer: VideoLayer) {
        guard let mpvGL = self.mpvGL else { return }
        
        self.layer = layer
        
        mpv_render_context_set_update_callback(
            mpvGL,
            glUpdate,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(layer).toOpaque())
        )
    }
    #endif
    
    func InitializeGLContext() {
        guard !initializedGLContext, mpv != nil else {
            return
        }
        let api = UnsafeMutableRawPointer(mutating: (MPV_RENDER_API_TYPE_OPENGL as NSString).utf8String)
        var initParams = mpv_opengl_init_params(
            get_proc_address: getProcAddress,
            get_proc_address_ctx: nil
        )
        
        withUnsafeMutablePointer(to: &initParams) { ptr in
            var params = [
                mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: api),
                mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: ptr),
                mpv_render_param()
            ]
            if mpv_render_context_create(
                &self.mpvGL,
                self.mpv,
                &params
            ) < 0 {
                #if DEBUG
                logger.error("failed to initialize mpv GL context")
                #endif
                exit(1)
            }
        }
        initializedGLContext = true
    }
    
    func destroy() {
        guard mpv != nil else { return }
        mpv_command_string(mpv, "stop")
        mpv_render_context_free(mpvGL)
        mpv_destroy(mpv)
        mpv = nil
        #if DEBUG
        logger.info("MPV instance destroyed.")
        #endif
    }
    
    func readEvents() {
        queue?.async(execute: { [weak self] in
            guard let self else { return }
            while self.mpv != nil {
                let event = mpv_wait_event(self.mpv, 0)
                if event!.pointee.event_id == MPV_EVENT_NONE {
                    break
                }
                player?.handle(event: event)
            }
        })
    }
    
    func loadFile(_ url: URL,
                  audio: URL? = nil,
                  sub: URL? = nil,
                  time: CMTime? = nil,
                  forceSeekable: Bool = false,
                  completionHandler: ((Int32) -> Void)? = nil) {
        var args = [url.absoluteString]
        var options = [String]()
        args.append("replace")
        args.append("-1")
        
        if let time, time.seconds > 0 {
            options.append("start=\(Int(time.seconds))")
        }

        if let audioURL = audio?.absoluteString {
            options.append("audio-files-append=\"\(audioURL)\"")
        }
        
        if let subURL = sub?.absoluteString {
            options.append("sub-files-append=\"\(subURL)\"")
        }
        
        if forceSeekable {
            options.append("force-seekable=yes")
            // this is needed for peertube?
            // options.append("stream-lavf-o=seekable=0")
        }
                
        if !options.isEmpty {
            args.append(options.joined(separator: ","))
        }
        command("loadfile", args: args, returnValueCallback: completionHandler)
    }
    
    
    func play() {
        setFlagAsync("pause", false)
    }
    
    func pause() {
        setFlagAsync("pause", true)
    }

    func togglePlay() {
        command("cycle", args: ["pause"])
    }

    func stop() {
        command("stop")
    }
            
    var currentTime: CMTime {
        CMTime.secondsInDefaultTimescale(mpv == nil ? -1 : getDouble("time-pos"))
    }
    
    var frameDropCount: Int {
        mpv == nil ? 0 : getInt("frame-drop-count")
    }
    
    var outputFps: Double {
        mpv == nil ? 0.0 : getDouble("estimated-vf-fps")
    }
    
    var hwDecoder: String {
        mpv == nil ? "unknown" : (getString("hwdec-current") ?? "unknown")
    }
    
    var bufferingState: Double {
        mpv == nil ? 0.0 : getDouble("cache-buffering-state")
    }
    
    var cacheDuration: Double {
        mpv == nil ? 0.0 : getDouble("demuxer-cache-duration")
    }
    
    var videoFormat: String {
        stringOrUnknown("video-format")
    }
    
    var videoCodec: String {
        stringOrUnknown("video-codec")
    }

    var currentVo: String {
        stringOrUnknown("current-vo")
    }

    var width: String {
        stringOrUnknown("width")
    }

    var height: String {
        stringOrUnknown("height")
    }
    
    var videoBitrate: Double {
        mpv == nil ? 0.0 : getDouble("video-bitrate")
    }
    
    var audioFormat: String {
        stringOrUnknown("audio-params/format")
    }

    var audioCodec: String {
        stringOrUnknown("audio-codec")
    }

    var currentAo: String {
        stringOrUnknown("current-ao")
    }

    var audioChannels: String {
        stringOrUnknown("audio-params/channels")
    }

    var audioSampleRate: String {
        stringOrUnknown("audio-params/samplerate")
    }
    
    var aspectRatio: Double {
        guard mpv != nil else { return MPVPlayer.defaultAspectRatio }
        let aspect = getDouble("video-params/aspect")
        return aspect.isZero ? MPVPlayer.defaultAspectRatio : aspect
    }
    
    var dh: Double {
        let defaultDh = 500.0
        guard mpv != nil else { return defaultDh }

        let dh = getDouble("video-params/dh")
        return dh.isZero ? defaultDh : dh
    }
    
    var duration: CMTime {
        CMTime.secondsInDefaultTimescale(mpv == nil ? -1 : getDouble("duration"))
    }
    
    var pausedForCache: Bool {
        mpv == nil ? false : getFlag("paused-for-cache")
    }

    var eofReached: Bool {
        mpv == nil ? false : getFlag("eof-reached")
    }
    
    var currentContainerFps: Int {
        guard mpv != nil else { return 30 }
        let fps = getDouble("container-fps")
        return Int(fps.rounded())
    }
    
    func areSubtitlesAdded() async -> Bool {
        guard mpv != nil else { return false }
        
        let trackCount = await withCheckedContinuation { continuation in
            continuation.resume(returning: getInt("track-list/count"))
        }
        
        guard trackCount > 0 else { return false }

        for index in 0 ..< trackCount {
            let trackType = await withCheckedContinuation { continuation in
                continuation.resume(returning: getString("track-list/\(index)/type"))
            }
            if trackType == "sub" {
                return true
            }
        }
        
        return false
    }
    
    func fetchTrackList() -> [MPVDiscoveredTrack] {
        guard mpv != nil else { return [] }
        
        var discoveredTracks: [MPVDiscoveredTrack] = []
        let trackCount = getInt("track-list/count")
        
        guard trackCount > 0 else { return [] }
        
        for i in 0..<trackCount {
            let prefix = "track-list/\(i)/"
            
            guard let typeStr = getString(prefix + "type"),
                  let idStr = getString(prefix + "id") else {
                continue
            }
            
            let type: MPVDiscoveredTrack.TrackType = {
                switch typeStr {
                case "audio": return .audio
                case "sub": return .subtitle
                default: return .unknown
                }
            }()
            
            guard type != .unknown else { continue }
            
            let lang = getString(prefix + "lang")
            let title = getString(prefix + "title")
            
            let track = MPVDiscoveredTrack(id: idStr, type: type, language: lang, title: title)
            discoveredTracks.append(track)
        }
        
        return discoveredTracks
    }
    
    
    func logCurrentFps() {
        #if DEBUG
        let fps = currentContainerFps
        logger.info("Current container FPS: \(fps)")
        #endif
    }
            
    func seek(relative time: CMTime, completionHandler: ((Bool) -> Void)? = nil) {
        guard !seeking else {
            #if DEBUG
            logger.warning("ignoring seek, another in progress")
            #endif
            return
        }
        
        seeking = true
        command("seek", args: [String(time.seconds)]) { [weak self] _ in
            self?.seeking = false
            completionHandler?(true)
        }
    }
    
    func seek(to time: CMTime, completionHandler: ((Bool) -> Void)? = nil) {
        guard !seeking else {
            #if DEBUG
            logger.warning("ignoring seek, another in progress")
            #endif
            return
        }

        seeking = true
        command("seek", args: [String(time.seconds), "absolute"]) { [weak self] _ in
            self?.seeking = false
            completionHandler?(true)
        }
    }
    
    @MainActor
    func setSize(_ width: Double, _ height: Double) {
        let roundedWidth = Int32(width.rounded() * 2) // HiDPI/Retina
        let roundedHeight = Int32(height.rounded() * 2) // HiDPI/Retina

        guard width > 0, height > 0 else {
            return
        }

        #if DEBUG
        logger.info("setting player size to \(roundedWidth),\(roundedHeight)")
        #endif
        
        #if canImport(UIKit)
        if let glView = self.glView {
            // The FBO size is updated within the draw method of MPVOGLView
            DispatchQueue.main.async {
                glView.frame = CGRect(x: 0, y: 0, width: width, height: height)
            }
        }
        #endif
    }
    
    @MainActor
    func setNeedsDrawing(_ needsDrawing: Bool) {
        // Check if we are currently in a cooldown period
        guard !needsDrawingCooldown else {
            #if DEBUG
            logger.info("Not drawing, cooldown in progress")
            #endif
            return
        }
        #if DEBUG
        logger.info("needs drawing: \(needsDrawing)")
        #endif

        // Set the cooldown flag to true and cancel any existing work item
        needsDrawingCooldown = true
        needsDrawingWorkItem?.cancel()

        #if canImport(UIKit)
        glView?.needsDrawing = needsDrawing
        #endif

        // Create a new DispatchWorkItem to reset the cooldown flag after 0.1 seconds
        let workItem = DispatchWorkItem { [weak self] in
            self?.needsDrawingCooldown = false
        }
        needsDrawingWorkItem = workItem

        // Schedule the cooldown reset after 0.1 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    func command(
        _ command: String,
        args: [String?] = [],
        checkForErrors: Bool = true,
        returnValueCallback: ((Int32) -> Void)? = nil
    ) {
        guard mpv != nil else {
            return
        }
        var cargs = makeCArgs(command, args).map { $0.flatMap { UnsafePointer<CChar>(strdup($0)) } }
        defer {
            for ptr in cargs where ptr != nil {
                free(UnsafeMutablePointer(mutating: ptr!))
            }
        }
        #if DEBUG
        logger.info("\(command) -- \(args)")
        #endif
        let returnValue = mpv_command(mpv, &cargs)
        if checkForErrors {
            checkError(returnValue)
        }
        if let cb = returnValueCallback {
            cb(returnValue)
        }
    }
    
    func updateRefreshRate(to refreshRate: Int) {
        setString("display-fps-override", "\(String(refreshRate))")
        #if DEBUG
        logger.info("Updated refresh rate during playback to: \(refreshRate) Hz")
        #endif
    }
    
    // Retrieve the screen's current refresh rate dynamically.
    @MainActor
    func getScreenRefreshRate() -> Int {
        var refreshRate = 60 // Default to 60 Hz in case of failure

        #if os(macOS)
            // macOS implementation using NSScreen
            if let screen = NSScreen.main,
               let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               let mode = CGDisplayCopyDisplayMode(displayID),
               mode.refreshRate > 0
            {
                refreshRate = Int(mode.refreshRate)
                #if DEBUG
                logger.info("Screen refresh rate: \(refreshRate) Hz")
                #endif
            } else {
                #if DEBUG
                logger.warning("Failed to get refresh rate from NSScreen.")
                #endif
            }
        #else
            // iOS implementation using UIScreen with a failover
            let mainScreen = UIScreen.main
            refreshRate = mainScreen.maximumFramesPerSecond

            // Failover: if maximumFramesPerSecond is 0 or an unexpected value
            if refreshRate <= 0 {
                refreshRate = 60 // Fallback to 60 Hz
                #if DEBUG
                logger.warning("Failed to get refresh rate from UIScreen, falling back to 60 Hz.")
                #endif
            } else {
                #if DEBUG
                logger.info("Screen refresh rate: \(refreshRate) Hz")
                #endif
            }
        #endif

        currentRefreshRate = refreshRate
        return refreshRate
    }
    
    func addVideoTrack(_ url: URL) {
        
        self.command("video-add", args: [url.absoluteString])
    }
    
    func addSubTrack(_ url: URL) async {
        await withCheckedContinuation { continuation in
            command("sub-add", args: [url.absoluteString])
            continuation.resume()
        }
    }
    
    func removeSubs() async {
        await withCheckedContinuation { continuation in
            command("sub-remove")
            continuation.resume()
        }
    }
    
    func setVideoToAuto() {
        setString("video", "1")
    }

    func setVideoToNo() {
        setString("video", "no")
    }
        
    func setSubToAuto() {
        setString("sub", "auto")
    }
        
    func setSubToNo() {
        setString("sub", "no")
    }
    
    func setSubFontSize(scaleSize: String) {
        setString("sub-scale", scaleSize)
    }
    
    func setSubFontColor(color: String) {
        setString("sub-color", color)
    }
    
    var tracksCount: Int {
        Int(getString("track-list/count") ?? "-1") ?? -1
    }
    
    private func getFlag(_ name: String) -> Bool {
        var data = Int64()
        mpv_get_property(mpv, name, MPV_FORMAT_FLAG, &data)
        return data > 0
    }
    
    private func setFlagAsync(_ name: String, _ flag: Bool) {
        guard mpv != nil else { return }
        var data: Int = flag ? 1 : 0
        mpv_set_property_async(mpv, 0, name, MPV_FORMAT_FLAG, &data)
    }
    
    func setDoubleAsync(_ name: String, _ value: Double) {
        guard mpv != nil else { return }
        var data = value
        mpv_set_property_async(mpv, 0, name, MPV_FORMAT_DOUBLE, &data)
    }
    
    func getDouble(_ name: String) -> Double {
        guard mpv != nil else { return 0.0 }
        var data = Double()
        mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
        return data
    }
    
    private func getInt(_ name: String) -> Int {
        guard mpv != nil else { return 0 }
        var data = Int64()
        mpv_get_property(mpv, name, MPV_FORMAT_INT64, &data)
        return Int(data)
    }

    func getString(_ name: String) -> String? {
        guard mpv != nil else { return nil }
        let cstr = mpv_get_property_string(mpv, name)
        let str: String? = cstr == nil ? nil : String(cString: cstr!)
        mpv_free(cstr)
        return str
    }

    func setString(_ name: String, _ value: String) {
        guard mpv != nil else { return }
        mpv_set_property_string(mpv, name, value)
    }
    
    private func makeCArgs(_ command: String, _ args: [String?]) -> [String?] {
        if !args.isEmpty, args.last == nil {
            fatalError("Command do not need a nil suffix")
        }

        var strArgs = args
        strArgs.insert(command, at: 0)
        strArgs.append(nil)

        return strArgs
    }
    
    private func checkError(_ status: CInt) {
        #if DEBUG
        if status < 0 {
            logger.error(.init(stringLiteral: "MPV API error: \(String(cString: mpv_error_string(status)))\n"))
        }
        #endif
    }
    
    private func stringOrUnknown(_ name: String) -> String {
        mpv == nil ? "unknown" : (getString(name) ?? "unknown")
    }
    
}


#if os(macOS)
    fileprivate func getProcAddress(_: UnsafeMutableRawPointer?, _ name: UnsafePointer<Int8>?) -> UnsafeMutableRawPointer? {
        let symbolName = CFStringCreateWithCString(kCFAllocatorDefault, name, CFStringBuiltInEncodings.ASCII.rawValue)
        let identifier = CFBundleGetBundleWithIdentifier("com.apple.opengl" as CFString)

        return CFBundleGetFunctionPointerForName(identifier, symbolName)
    }

    func glUpdate(_ ctx: UnsafeMutableRawPointer?) {
        let videoLayer = unsafeBitCast(ctx, to: VideoLayer.self)

        videoLayer.client?.queue?.async {
            if !videoLayer.isAsynchronous {
                videoLayer.display()
            }
        }
    }
#else
fileprivate func getProcAddress(_: UnsafeMutableRawPointer?, _ name: UnsafePointer<Int8>?) -> UnsafeMutableRawPointer? {
    let symbolName = CFStringCreateWithCString(kCFAllocatorDefault, name, CFStringBuiltInEncodings.ASCII.rawValue)
    let identifier = CFBundleGetBundleWithIdentifier("com.apple.opengles" as CFString)

    return CFBundleGetFunctionPointerForName(identifier, symbolName)
}


fileprivate func glUpdate(_ ctx: UnsafeMutableRawPointer?) {
    let glView = unsafeBitCast(ctx, to: MPVOGLView.self)
    Task { @MainActor in
        guard glView.needsDrawing else {
            return
        }
        glView.display()
    }
}

#endif

fileprivate func wakeUp(_ context: UnsafeMutableRawPointer?) {
    let client = unsafeBitCast(context, to: MPVClient.self)
    client.readEvents()
}
