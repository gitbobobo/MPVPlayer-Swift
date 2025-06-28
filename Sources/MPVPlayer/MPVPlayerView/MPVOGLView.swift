//
//  MPVOGLView.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

#if canImport(UIKit)
import Foundation
import GLKit
import Libmpv
import OpenGLES

final class MPVOGLView: GLKView {
    #if DEBUG
    private var logger = PackageLogger.shared
    #endif
    
    private var defaultFBO: GLint?
    private var displayLink: CADisplayLink?

    var mpvGL: UnsafeMutableRawPointer?
    var queue = DispatchQueue(label: "package.MPVPlayer.opengl", qos: .userInteractive)
    var needsDrawing = true
    private var dirtyRegion: CGRect?
    
    
    override init(frame: CGRect) {
        guard let context = EAGLContext(api: .openGLES2) else {
            print("Failed to initialize OpenGLES 2.0 context")
            exit(1)
        }
        
        #if DEBUG
        logger.debug("frame size: \(frame.width) x \(frame.height)")
        #endif
        super.init(frame: frame, context: context)

        self.context = context
        bindDrawable()

        defaultFBO = -1
        isOpaque = true
        enableSetNeedsDisplay = false

        fillBlack()
        setupDisplayLink()
        setupNotifications()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupDisplayLink()
        setupNotifications()
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    // Set up observers to detect display changes and custom refresh rate updates.
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateDisplayLinkFromNotification(_:)), name: .updateDisplayLinkFrameRate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenDidChange), name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenDidChange), name: UIScreen.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenDidChange), name: UIScreen.modeDidChangeNotification, object: nil)
    }
    
    @objc private func screenDidChange(_: Notification) {
        // Update the display link refresh rate when the screen configuration changes
        updateDisplayLinkFrameRate()
    }
    
    // Update the display link frame rate from the notification.
    @objc private func updateDisplayLinkFromNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let refreshRate = userInfo["refreshRate"] as? Int else { return }
        displayLink?.preferredFramesPerSecond = refreshRate
        #if DEBUG
        logger.info("Updated CADisplayLink frame rate to: \(refreshRate) from backend notification.")
        #endif
    }

    // Update the display link's preferred frame rate based on the current screen refresh rate.
    private func updateDisplayLinkFrameRate() {
        guard let displayLink else { return }
        let refreshRate = getScreenRefreshRate()
        displayLink.preferredFramesPerSecond = refreshRate
        #if DEBUG
        logger.info("Updated CADisplayLink preferred frames per second to: \(refreshRate)")
        #endif
    }
    
    // Retrieve the screen's current refresh rate dynamically.
    private func getScreenRefreshRate() -> Int {
        // Use the main screen's maximumFramesPerSecond property
        let refreshRate = UIScreen.main.maximumFramesPerSecond
        #if DEBUG
        logger.info("Screen refresh rate: \(refreshRate) Hz")
        #endif
        return refreshRate
    }
    
    @objc private func updateFrame() {
        // Trigger the drawing process if needed
        if needsDrawing {
            markRegionAsDirty(bounds)
            setNeedsDisplay()
        }
    }
    
    
    deinit {
        // Invalidate the display link and remove observers to avoid memory leaks
        Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }
    
    func fillBlack() {
        glClearColor(0, 0, 0, 0)
        glClear(UInt32(GL_COLOR_BUFFER_BIT))
    }
    
    // Function to set a dirty region when a part of the screen changes
    func markRegionAsDirty(_ region: CGRect) {
        if dirtyRegion == nil {
            dirtyRegion = region
        } else {
            // Expand the dirty region to include the new region
            dirtyRegion = dirtyRegion!.union(region)
        }
    }
    
    // Logic to decide if only part of the screen needs updating
    private func needsPartialUpdate() -> Bool {
        // Check if there is a defined dirty region that needs updating
        if let dirtyRegion, !dirtyRegion.isEmpty {
            // Set up glScissor based on dirtyRegion coordinates
            glScissor(GLint(dirtyRegion.origin.x), GLint(dirtyRegion.origin.y), GLsizei(dirtyRegion.width), GLsizei(dirtyRegion.height))
            return true
        }
        return false
    }
    
    // Call this function when you know the entire screen needs updating
    private func clearDirtyRegion() {
        dirtyRegion = nil
    }
    
    override func draw(_: CGRect) {
        guard needsDrawing, let mpvGL else { return }

        // Ensure the correct context is set
        guard EAGLContext.setCurrent(context) else {
            #if DEBUG
            logger.error("Failed to set current OpenGL context.")
            #endif
            return
        }

        // Bind the default framebuffer
        glGetIntegerv(UInt32(GL_FRAMEBUFFER_BINDING), &defaultFBO!)

        // Ensure the framebuffer is valid
        guard defaultFBO != nil && defaultFBO! != 0 else {
            #if DEBUG
            logger.error("Invalid framebuffer ID.")
            #endif
            return
        }

        // Get the current viewport dimensions
        var dims: [GLint] = [0, 0, 0, 0]
        glGetIntegerv(GLenum(GL_VIEWPORT), &dims)

        // Check if we need partial updates
        if needsPartialUpdate() {
            glEnable(GLenum(GL_SCISSOR_TEST))
        }

        // Set up the OpenGL FBO data
        var data = mpv_opengl_fbo(
            fbo: Int32(defaultFBO!),
            w: Int32(dims[2]),
            h: Int32(dims[3]),
            internal_format: 0
        )

        // Flip Y coordinate for proper rendering
        var flip: CInt = 1

        // Render with the provided OpenGL FBO parameters
        withUnsafeMutablePointer(to: &flip) { flipPtr in
            withUnsafeMutablePointer(to: &data) { dataPtr in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: dataPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_FLIP_Y, data: flipPtr),
                    mpv_render_param()
                ]
                // Call the render function and check for errors
                _ = mpv_render_context_render(OpaquePointer(mpvGL), &params)
            }
        }

        // Disable the scissor test after rendering if it was enabled
        if needsPartialUpdate() {
            glDisable(GLenum(GL_SCISSOR_TEST))
        }

        // Clear dirty region after drawing
        clearDirtyRegion()
    }
    
    private func cleanup() {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

extension Notification.Name {
    static let updateDisplayLinkFrameRate = Notification.Name("updateDisplayLinkFrameRate")
}
#endif
