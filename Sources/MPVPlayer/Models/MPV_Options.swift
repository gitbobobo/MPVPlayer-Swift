//
//  MPVOptions.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Libmpv

public enum MPVOptions: CaseIterable, Sendable {
    
    public static let allCases: [MPVOptions] = [
        .cachePauseInitial, .cacheSecs, .cachePauseWait, .keepOpen, .deinterlace, .subScale, .subColor, .userAgent, .initialAudioSync, .openglSwapinterval, .videoSync, .interpolation, .tscale, .tscaleWindow, .vdLavcFramedrop, .hwdec, .vo, .gpuAPI, .openglES, .dither, .demuxer, .audioDemuxer, .subDemuxer, .demuxerLavfAnalyzeduration, .demuxerLavfProbeInfo
    ]
    
    case cachePauseInitial
    case cacheSecs
    case cachePauseWait
    case keepOpen
    case deinterlace
    case subScale
    case subColor
    case userAgent
    case initialAudioSync
    case openglSwapinterval
    case videoSync
    case interpolation
    case tscale
    case tscaleWindow
    case vdLavcFramedrop
    /// Hardware decoder
    case hwdec
    case vo
    case gpuAPI
    case openglES
    case dither
    case demuxer
    case audioDemuxer
    case subDemuxer
    case demuxerLavfAnalyzeduration
    case demuxerLavfProbeInfo
    case anyOption(_ optionString: String, value: String)
}

public extension MPVOptions {
    
    /// Setup MPV Opetion
    /// - Parameters:
    ///   - mpv: MPV instance
    ///   - value: If NIl, the default value is used
    func setupDefault(with mpv: OpaquePointer, value: String? = nil) {
        guard value != nil || self.defaultEnabeld else {
            return
        }
        checkError(mpv_set_option_string(mpv, self.optionString, (value ?? self.default)))
    }
    
    var optionString: String {
        switch self {
        case .cachePauseInitial:
            return "cache-pause-initial"
        case .cacheSecs:
            return "cache-secs"
        case .cachePauseWait:
            return "cache-pause-wait"
        case .keepOpen:
            return "keep-open"
        case .deinterlace:
            return "deinterlace"
        case .subScale:
            return "sub-scale"
        case .subColor:
            return "sub-color"
        case .userAgent:
            return "user-agent"
        case .initialAudioSync:
            return "initial-audio-sync"
        case .openglSwapinterval:
            return "opengl-swapinterval"
        case .videoSync:
            return "video-sync"
        case .interpolation:
            return "interpolation"
        case .tscale:
            return "tscale"
        case .tscaleWindow:
            return "tscale-window"
        case .vdLavcFramedrop:
            return "vd-lavc-framedrop"
        case .hwdec:
            return "hwdec"
        case .vo:
            return "vo"
        case .gpuAPI:
            return "gpu-api"
        case .openglES:
            return "opengl-es"
        case .dither:
            return "dither"
        case .demuxer:
            return "demuxer"
        case .audioDemuxer:
            return "audio-demuxer"
        case .subDemuxer:
            return "sub-demuxer"
        case .demuxerLavfAnalyzeduration:
            return "demuxer-lavf-analyzeduration"
        case .demuxerLavfProbeInfo:
            return "demuxer-lavf-probe-info"
        case .anyOption(let option, value: _):
            return option
        }
    }
}


public extension MPVOptions {
    var `default`: String {
        switch self {
        case .cachePauseInitial:
            return "no"
        case .cacheSecs:
            return "120"
        case .cachePauseWait:
            return "3"
        case .keepOpen:
            return "yes"
        case .deinterlace:
            return "no"
        case .subScale:
            return "1.0"
        case .subColor:
            return "#FFFFFF"
        case .userAgent:
            return "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)"
        case .initialAudioSync:
            return "yes"
        case .openglSwapinterval:
            return "1"
        case .videoSync:
            return "display-resample"
        case .interpolation:
            return "yes"
        case .tscale:
            return "mitchell"
        case .tscaleWindow:
            return "blackman"
        case .vdLavcFramedrop:
            return "nonref"
        case .hwdec:
            return "auto-safe"
        case .vo:
            return "libmpv"
        case .gpuAPI:
            return "opengl"
        case .openglES:
            return "yes"
        case .dither:
            return "ordered"
        case .demuxer:
            return "lavf"
        case .audioDemuxer:
            return "lavf"
        case .subDemuxer:
            return "lavf"
        case .demuxerLavfAnalyzeduration:
            return "1"
        case .demuxerLavfProbeInfo:
            return "no"
        case .anyOption(_, value: let value):
            return value
        }
    }
    
    private func checkError(_ status: CInt) {
        #if DEBUG
        if status < 0 {
            PackageLogger.shared.error(.init(stringLiteral: "MPV Send error when setting \(self.optionString) options.: \(String(cString: mpv_error_string(status)))\n"))
        }
        #endif
    }
    
    var defaultEnabeld: Bool {
        switch self {
        case .openglSwapinterval, .videoSync, .interpolation, .tscale, .tscaleWindow, .vdLavcFramedrop, .gpuAPI:
            return false
        case .openglES:
            #if canImport(AppKit)
            return false
            #else
            return true
            #endif
        default:
            return true
        }
    }
    
    @preconcurrency @MainActor
    fileprivate static func getRefreshRate() -> Int {
        #if canImport(UIKit)
        let rate = UIScreen.main.maximumFramesPerSecond
        return rate > 0 ? rate : 60
        #elseif canImport(AppKit)
        var rate = 60
        if let screen = NSScreen.main,
           let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
           let mode = CGDisplayCopyDisplayMode(displayID),
           mode.refreshRate > 0
        {
            rate = Int(mode.refreshRate)
        }
        return rate
        #endif
    }
    
    @MainActor
    static func overrideDisplayFPS(with mpv: OpaquePointer) {
        let refreshRate = getRefreshRate()
        let refreshRateString = "\(String(refreshRate))"
        let opt = Self.anyOption("display-fps-override", value: refreshRateString)
        opt.setupDefault(with: mpv)
    }
}

