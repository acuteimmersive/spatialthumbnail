//
//  CMTaggedBuffer+Data.swift
//  Spatial Thumbnail
//
//  Created by Anthony Maës (Acute Immersive) on 10/31/24.
//

import AVKit
import VideoToolbox

extension CMTaggedBuffer
{
    enum DataError: Error {
        case NoCVPixelBuffer
        case CGImageCreationFailed
        case NoJPEGImageRepresentation
    }
    
    /// Returns the Stereo View Component, that is to say, the tag specifying eye corresponds to the present buffer,
    /// assuming the buffer comes from a stereoscopic video.
    /// - Returns: the eye for the current buffer.
    public func stereoViewComponent() -> CMStereoViewComponents? {
        return tags.firstValue(matchingCategory: .stereoView)
    }
    
    /// Returns the `CVPixelBuffer` contained in the buffer; throws if none.
    /// - Returns: the pixel buffer.
    public func cvPixelBuffer() throws -> CVPixelBuffer {
        switch (buffer) {
        case .pixelBuffer(let pixelBuffer):
            return pixelBuffer
        case .sampleBuffer(_):
            fallthrough
        @unknown default:
            throw DataError.NoCVPixelBuffer
        }
    }
    
    /// Returns the `NSBitmapImageRep` created by way of the buffer's `CVPixelBuffer`. Throws if none.
    /// - Returns: the bitmap image representation.
    public func nsBitmapImageRep() throws -> NSBitmapImageRep {
        let pixelBuffer = try cvPixelBuffer()
        var image: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        guard let image else {
            throw DataError.CGImageCreationFailed
        }
        return NSBitmapImageRep(cgImage: image)
    }
    
    /// Writes the contents of the buffer's `CVPixelBuffer` as a JPEG file to the specified URL. Throws if none.
    /// - Parameters:
    ///   - url: the URL to a file path where to write the file.
    public func writeJPEG(to url: URL) throws {
        let bits = try nsBitmapImageRep()
        guard let data = bits.representation(using: .jpeg, properties: [:]) else {
            throw DataError.NoJPEGImageRepresentation
        }
        
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
        try data.write(to: url)
    }
}

