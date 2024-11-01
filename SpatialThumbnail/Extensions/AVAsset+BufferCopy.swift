//
//  AVAsset+BufferCopy.swift
//  Spatial Thumbnail
//
//  Created by Anthony Maës (Acute Immersive) on 10/31/24.
//

import VideoToolbox
@preconcurrency import AVKit

extension AVAssetTrack
{
    /// Queries the track for available video layer IDs.
    /// - Returns: the array of available layer IDs for the track.
    ///
    /// In Spatial Video (MV-HEVC) those are typically `[0, 1]` but might be other values.
    public func loadVideoLayerIds() async throws -> [Int64] {
        let formatDescriptions = try await load(.formatDescriptions)
        
        var tags = [Int64]()
        if let tagCollections = formatDescriptions.first?.tagCollections {
            tags = tagCollections.flatMap({ $0 }).compactMap { tag in
                tag.value(onlyIfMatching: .videoLayerID)
            }
        }
        return tags
    }
}

extension AVAsset
{
    enum BufferCopyError: Error {
        case MissingVideoTrack
        case MissingSampleBuffer
        case MissingTaggedBuffers
    }
    
    /// Loads the video track, throws if none.
    /// - Returns: the first video track.
    public func loadVideoTrack() async throws -> AVAssetTrack {
        let tracks = try await load(.tracks)
        guard let track = tracks.first(where: { $0.mediaType == .video }) else {
            throw BufferCopyError.MissingVideoTrack
        }
        return track
    }
    
    /// Creates an `AVAssetReaderTrackOutput` for the video track, configured to read multiple video layers.
    /// - Returns: a ready to use AVAssetReaderTrackOutput.
    public func makeAssetReaderTrackOutput() async throws -> AVAssetReaderTrackOutput {
        let videoTrack = try await loadVideoTrack()
        let ids = try await videoTrack.loadVideoLayerIds()
        
        // Configuration to explicitly require reading multiple layers when opening an AssetReaderTrackOutput
        // https://forums.developer.apple.com/forums/thread/742971
        var outputSettings: [String: Any] = [:]
        var decompressionProperties: [String: Any] = [:]
        decompressionProperties[kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs as String] = ids
        outputSettings[AVVideoDecompressionPropertiesKey] = decompressionProperties
        
        return AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        
    }
    
    /// Copies video buffers for multiple layers at the specified time.
    /// - Parameters:
    ///   - time: the video time of the frame that should be snapshotted.
    /// - Returns: an array of two `CMTaggedBuffer` containing the decoded pixel data for each eye for the frame at the specified time.
    public func copyBuffers(at time: CMTime) async throws -> [CMTaggedBuffer] {
        let assetReader = try AVAssetReader(asset: self)
        let trackOutput = try await makeAssetReaderTrackOutput()
        assetReader.add(trackOutput)
        assetReader.timeRange = CMTimeRange(start: time, duration: .invalid)
        assetReader.startReading()
        
        guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
            if let error = assetReader.error {
                throw error
            }
            throw BufferCopyError.MissingSampleBuffer
        }
        guard let taggedBuffers = sampleBuffer.taggedBuffers else {
            throw BufferCopyError.MissingTaggedBuffers
        }
        return taggedBuffers
    }
}
