//
//  ContentView.swift
//  MPVPlayerExample
//
//  Created by Zain Wu on 2025/6/28.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: VideoPlayerView()) {
                    Text("Play Sample Video")
                }
                
                NavigationLink(destination: AudioPlayerView()) {
                    Text("Play Sample Audio")
                }
            }
            #if !os(macOS)
            .navigationBarTitle("MPVPlayer Example")
            #endif
        }
        #if !os(macOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
}

#Preview {
    ContentView()
}
