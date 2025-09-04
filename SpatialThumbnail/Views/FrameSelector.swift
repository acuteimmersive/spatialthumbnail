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
    /// The current pixel size of the video
    @State var videoSize: CGSize?
    /// The current orientation of the video
    @State var videoTransform: CGAffineTransform?
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
    
    /// Whether cropping is active.
    @State var crop: Bool = false
    /// The offset of the crop, in video coordinates.
    @State var cropOffset: CGPoint = .zero
    /// The width of the crop, in video coordinates.
    @State var cropWidth: CGFloat = 0
    /// The height of the crop, in video coordinates.
    @State var cropHeight: CGFloat = 0
    /// The crop rect in video coordinates.
    var cropRect: CGRect? {
        guard crop, cropWidth > 0, cropHeight > 0 else { return nil }
        return CGRect(
            x: cropOffset.x,
            y: cropOffset.y,
            width: cropWidth,
            height: cropHeight
        )
    }
    
    /// The max size of the player in the window.
    let playerMaxSize = CGSize(width: 1280, height: 720)
    /// The size of the player in the window.
    var playerSize: CGSize {
        guard let videoSize else { return CGSize(width: 480, height: 320) }
        if playerMaxSize.height / videoSize.height > playerMaxSize.width / videoSize.width {
            // video fills the player horizontally
            return CGSize(width: playerMaxSize.width, height: videoSize.height * playerScale)
        } else {
            // video fills the player vertically
            return CGSize(width: videoSize.width * playerScale, height: playerMaxSize.height)
        }
    }
    
    /// The number of video pixels per player view coordinate points.
    var playerScale: CGFloat {
        guard let videoSize else { return 1 }
        return min(playerMaxSize.width / videoSize.width, playerMaxSize.height / videoSize.height )
    }
    
    var body: some View {
        VStack {
            HStack {
                FilePicker() { url, isSecurityScoped in
                    loadUrl(url, isSecurityScoped: isSecurityScoped)
                }
                
                Button("Screenshot", systemImage: "photo.tv") {
                    takeScreenshot()
                }
                .disabled(player.currentItem == nil)
                
                Toggle("Crop", systemImage: "crop", isOn: $crop)
                    .toggleStyle(.button)
                    .disabled(player.currentItem == nil)
                    .onChange(of: crop) { _, _ in
                        cropOffset = .zero
                        cropWidth = 0
                        cropHeight = 0
                    }
                
                if crop {
                    TextField("Width", value: $cropWidth, formatter: NumberFormatter())
                        .frame(maxWidth: 50)
                    TextField("Height", value: $cropHeight, formatter: NumberFormatter())
                        .frame(maxWidth: 50)
                }
            }
            .padding()
            
            VideoPlayer(player: player) {
                CropRectangle(
                    playerSize: playerSize,
                    playerScale: playerScale,
                    cropOffset: $cropOffset,
                    cropWidth: $cropWidth,
                    cropHeight: $cropHeight
                )
                .disabled(!crop)
            }
            .aspectRatio(contentMode: .fit)
            
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
        
        crop = false
        videoSize = nil
        videoTransform = nil
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        currentItemIsSecurityScoped = isSecurityScoped
        
        status = .idle
        message = "Loaded Video: \(url.path())"
        
        Task {
            if let (size, transform) = try? await asset.loadSize() {
                videoSize = size
                videoTransform = transform
            }
        }
    }
    
    /// Takes a screenshot of the current frame and save the spatial photo and left/right eyes
    func takeScreenshot() {
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
        
        asset.screenshot(at: currentTime, transform: videoTransform, crop: cropRect) { (success, message) in
            Task { @MainActor in
                self.status = success ? .success : .failure
                self.message = message
            }
        }
    }
}

#Preview {
    FrameSelector()
}
