<div align="center">

# 🎬 MPVPlayer

**An elegant, AVPlayer-like Swift wrapper for the powerful mpv media player.**

</div>

<p align="center">
  <img alt="Swift Version" src="https://img.shields.io/badge/Swift-5.10+-orange?logo=swift">
  <img alt="Platforms" src="https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20tvOS-blue">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-green">
</p>

`MPVPlayer` provides a modern, Swifty interface for `libmpv`, allowing developers to integrate the high-performance mpv player into their Apple platform applications with ease. The API is intentionally designed to be familiar to anyone who has worked with Apple's native `AVPlayer`, significantly lowering the learning curve.

Whether you are building a complex media center in UIKit/AppKit or a lightweight video player in SwiftUI, `MPVPlayer` offers the tools you need to get started quickly.

## ✨ Features

- **AVPlayer-Style API**: Familiar method names like `play()`, `pause()`, `seek(to:)`, and `replaceCurrentItem(with:)`.
- **Modern & Swifty**: Built with modern Swift, using `async/await` and Combine to provide a robust, thread-safe interface.
- **Cross-Platform**: A single codebase supporting macOS, iOS, and tvOS.
- **Audio + Video Support**: Natively handles both video and audio-only media items.
- **Rich Playback Information**: Easily access detailed playback metrics, statistics, and diagnostics.
- **Powerful UI Components**:
  - `MPVPlayerViewController`: A ready-to-use `NSViewController`/`UIViewController` subclass for deep integration.
  - `MPVPlayerView`: A simple and powerful `SwiftUI` view for declarative UIs.
- **State Monitoring**: Observe playback status (`.playing`, `.paused`, `.waitingToPlay`) and receive notifications for events like end-of-playback.


## 📋 Requirements

- macOS 10.15+
- iOS 13+
- tvOS 13+
- Xcode 15.0+
- Swift 5.10+

## 📦 Installation

You can add `MPVPlayer` to your project using Swift Package Manager.

1. In Xcode, select **File > Add Packages...**
2. Paste the repository URL: `https://github.com/wxyjay/MPVPlayer-Swift.git`
3. Select the package and add it to your project.

## 🚀 Usage Guide

Here’s how you can use `MPVPlayer` in your project.

### 1. Basic Usage (Player Control)

This example shows the fundamental logic of creating a player, loading an item, and controlling playback.

```swift
import SwiftUI
import MPVPlayer // 1. Import the package

// 2. Create and retain a player instance
let player = MPVPlayer()

// 3. Create a player item
guard let url = URL(string: "http://...") else { return }
let item = MPVPlayerItem(videoURL: url)

// 4. Load the item and start playback
player.replaceCurrentItem(with: item)
// The player will automatically start playing.

// 5. Control playback
player.pause()
player.play()
player.seek(to: CMTime(seconds: 30, preferredTimescale: 600))
```

### 2. Using with SwiftUI (Recommended)

The easiest way to display the player in a SwiftUI application is by using the `MPVPlayerView`.

```swift
import SwiftUI
import MPVPlayer

struct MyVideoView: View {
    // Use @StateObject to manage the player's lifecycle
    @StateObject private var player = MPVPlayer()

    var body: some View {
        VStack {
            // 1. Add the player view to your hierarchy
            MPVPlayerView(player: player)

            // 2. Add your custom controls
            HStack {
                Button("Play", action: player.play)
                Button("Pause", action: player.pause)
            }
            .padding()
        }
        .onAppear {
            // 3. Load the media when the view appears
            guard let url = URL(string: "http://...") else { return }
            let item = MPVPlayerItem(videoURL: url)
            player.replaceCurrentItem(with: item)
        }
    }
}
```

### 3. Using with UIKit / AppKit

For more complex scenarios or non-SwiftUI apps, you can use the `MPVPlayerViewController`.

```swift
import UIKit
import MPVPlayer

class MyViewController: UIViewController {
    let player = MPVPlayer()
    var playerViewController: MPVPlayerViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Initialize the player view controller
        playerViewController = MPVPlayerViewController(player: player)
        
        // 2. Add it as a child view controller
        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)
        
        // 3. Set its frame
        playerViewController.view.frame = view.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 4. Load media
        guard let url = URL(string: "http://...") else { return }
        let item = MPVPlayerItem(videoURL: url)
        player.replaceCurrentItem(with: item)
    }
}
```

## 📚 Example Project

This package includes a detailed example project demonstrating a complete MVVM architecture, advanced state observation, track selection, and more. For more advanced usage, please explore the `MPVPlayerExample` target.

## 🔗 Dependencies

This project relies on the following excellent open-source libraries:

- [MPVKit](https://github.com/mpvkit/MPVKit) for managing the `mpv.xcframework`.
- [Repeat](https://github.com/malcommac/Repeat) for easy-to-use timers.

## 🙏 Acknowledgements

This package would not be possible without the incredible work of the entire `mpv` team and the broader open-source community.

Special thanks to the **[Yattee](https://github.com/yattee/yattee)** project. The low-level `mpv` C-to-Swift interoperability and OpenGL view implementation in this package were heavily referenced from and inspired by their robust and well-designed codebase.

We are immensely grateful for these projects.

## 📄 License

This package is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
```

