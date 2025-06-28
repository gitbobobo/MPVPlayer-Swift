//
//  StreamableItem.swift
//  MPVPlayerExample
//
//  Created by Zain Wu on 2025/6/28.
//

import Foundation

/// Represents a single streamable media item, which can be either video or audio.
struct StreamableItem: Identifiable, Hashable {
    
    enum MediaType {
        case video
        case audio
    }
    
    let id = UUID()
    let title: String
    let url: URL
    let type: MediaType
}

/// A static data source for sample media items used in the example app.
enum SampleMedia {
    /*
     
     https://gist.github.com/jsturgis/3b19447b304616f18657
     
     
     */
    static let bigBuckBunny = StreamableItem(
        title: "Sample mp4 (Video)",
        url: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4")!,
        type: .video
    )
    
    /*
     
     https://github.com/rafaelreis-hotmart/Audio-Sample-files?tab=readme-ov-file
     Sample using file sample.mp3
     
     */
    static let harpsiCs = StreamableItem(
        title: "Sample mp3 (Audio)",
        url: URL(string: "https://github.com/rafaelreis-hotmart/Audio-Sample-files/raw/master/sample.mp3")!,
        type: .audio
    )
}
