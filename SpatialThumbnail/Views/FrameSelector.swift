//
//  FrameSelector.swift
//  Spatial Thumbnail
//
//  Created by Anthony Maës (Acute Immersive) on 10/29/24.
//

import SwiftUI
import AVKit

/// The main view of the app, presents a video player with a couple of controls.
struct FrameSelector: View {
    /// The player underlying the `VideoPlayer` contained in the view.
    @State var player = AVPlayer()
    /// Whether the currently selected media item is security scoped (needs to be released on unload).
    @State var currentItemIsSecurityScoped = false
    
    enum Status: String {
        case idle = ""
        case processing = "⏳"
        case success = "✅"
        case failure = "⚠️"
    }
    /// The latest status of the app.
    @State var status: Status = .idle
    /// The latest status message from the app.
    @State var message: String = ""
    
    var body: some View {
        VStack {
            HStack {
                FilePicker() { url, isSecurityScoped in
                    loadUrl(url, isSecurityScoped: isSecurityScoped)
                }
                
                Button("Screenshot", systemImage: "photo.tv") {
                    guard let asset = player.currentItem?.asset as? AVURLAsset else {
                        status = .failure
                        message = "No valid video item selected."
                        return
                    }
                    
                    let currentTime = player.currentTime()
                    let duration = Duration.seconds(currentTime.seconds)
                        .formatted(
                            .time(pattern:
                                    .minuteSecond(
                                        padMinuteToLength: 0,
                                        fractionalSecondsLength: 3)))
                    status = .processing
                    message = "Taking Screenshot at \(duration)..."
                    
                    asset.screenshot(at: currentTime) { (success, message) in
                        Task { @MainActor in
                            self.status = success ? .success : .failure
                            self.message = message
                        }
                    }
                }
            }
            .padding()
            
            VideoPlayer(player: player)
            
            HStack {
                Text(status.rawValue)
                
                Text(message)
            }
            .padding()
        }
    }
    
    /// Loads the video item at the specified URL
    /// - Parameters:
    ///   - url: the URL to the file path to the media item.
    ///   - isSecurityScoped: true if the URL is security scoped, and the resource needs to be released later.
    ///
    /// If the URL points to an online resource, as opposed to a local file, screenshots cannot be created.
    func loadUrl(_ url: URL, isSecurityScoped: Bool) {
        if currentItemIsSecurityScoped,
           let asset = player.currentItem?.asset as? AVURLAsset {
            asset.url.stopAccessingSecurityScopedResource()
        }
        
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        currentItemIsSecurityScoped = isSecurityScoped
        
        status = .idle
        message = "Loaded Video: \(url.path())"
    }
}

#Preview {
    FrameSelector()
}
