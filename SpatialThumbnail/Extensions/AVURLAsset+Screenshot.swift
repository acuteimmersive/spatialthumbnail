//
//  AVURLAsset+Screenshot.swift
//  Spatial Thumbnail
//
//  Created by Anthony Maës (Acute Immersive) on 10/31/24.
//

import AVKit
import SwiftUICore

extension AVURLAsset {
    enum ScreenshotError: Error {
        case WrongNumberOfBuffers(buffers: Int)
    }
    
    /// Saves left eye and right eye JPEG files for the frame at the given time
    /// and combines them into a stereoscopic HEIC image file.
    /// - Parameters:
    ///   - time: the time of the frame that needs to be saved.
    ///   - callback: the optional closure to be executed when the screenshot call succeeds or fails.
    ///
    /// The bulk of this function runs in its own task thread.
    public func screenshot(at time: CMTime, callback: sending ((Bool, String) -> Void)? = nil) {
        let timeStr = String(format: "%.0f", time.seconds * 1000)
        let baseUrl = url.deletingPathExtension().appendingPathExtension(timeStr)
        let leftUrl = baseUrl.appendingPathExtension("left.jpg")
        let rightUrl = baseUrl.appendingPathExtension("right.jpg")
        let outputUrl = baseUrl.appendingPathExtension("heic")
        
        Task {
            do {
                let buffers = try await copyBuffers(at: time)
                
                var eyes = 0
                try buffers.forEach { taggedBuffer in
                    guard let eye = taggedBuffer.stereoViewComponent() else {
                        return
                    }
                    
                    let url = eye == .rightEye ? rightUrl : leftUrl
                    try taggedBuffer.writeJPEG(to: url)
                    eyes += 1
                }
                
                guard eyes == 2 else {
                    throw ScreenshotError.WrongNumberOfBuffers(buffers: eyes)
                }
                let converter = SpatialPhotoConverter(
                    leftImageURL: leftUrl,
                    rightImageURL: rightUrl,
                    outputImageURL: outputUrl,
                    baselineInMillimeters: 60,
                    horizontalFOV: 170,
                    disparityAdjustment: 0
                )

                if FileManager.default.fileExists(atPath: outputUrl.path()) {
                    try FileManager.default.removeItem(at: outputUrl)
                }

                try converter.convert()
                
                callback?(true, "Saved to \(outputUrl.path())")
            } catch {
                callback?(false, String(describing: error))
            }
        }
    }
}
