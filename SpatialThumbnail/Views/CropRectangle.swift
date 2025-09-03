//
//  CropRectangle.swift
//  Spatial Thumbnail
//
//  Created by Anthony Maës on 9/4/25.
//

import SwiftUI

/// The video player overlay, for drawing and rendering the crop rectangle.
struct CropRectangle: View {
    /// The full size of the video player's frame, in view coordinates.
    let playerSize: CGSize
    /// The number of video pixels per player view coordinate points.
    let playerScale: CGFloat
    /// The offset of the crop rectangle in video coordinates.
    @Binding var cropOffset: CGPoint
    /// The width of the crop rectangle in video coordinates.
    @Binding var cropWidth: CGFloat
    /// The height of the crop rectangle in video coordinates.
    @Binding var cropHeight: CGFloat
    
    /// The variable for animating the rectangle color.
    @State var animation = false
    /// Are we in the middle of a rectangle dragging?
    @State var dragging: Bool = false
    /// The original offset of the crop rectangle in view coordinates.
    @State var draggedCropOffset: CGPoint? = nil
    
    /// The crop rectangle in player view coordinates.
    var cropRect: CGRect {
        CGRect(
            x: cropOffset.x * playerScale,
            y: cropOffset.y * playerScale,
            width: cropWidth * playerScale,
            height: cropHeight * playerScale
        )
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            
            if !cropRect.isEmpty {
                let dimColor = Color.black.opacity(0.4)
                if cropRect.minX > 0 {
                    dimColor.frame(width: cropRect.minX, height: playerSize.height)
                }
                if cropRect.maxX < playerSize.width {
                    dimColor.frame(width: playerSize.width - cropRect.maxX, height: playerSize.height)
                        .offset(x: cropRect.maxX, y: 0)
                }
                if cropRect.minY > 0 {
                    dimColor.frame(width: cropRect.width, height: cropRect.minY)
                        .offset(x: cropRect.minX, y: 0)
                }
                if cropRect.maxY < playerSize.height {
                    dimColor.frame(width: cropRect.width, height: playerSize.height - cropRect.maxY)
                        .offset(x: cropRect.minX, y: cropRect.maxY)
                }
                
                let strokeColor = animation ? Color.gray : Color.white
                Rectangle()
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
                    .frame(width: cropRect.width, height: cropRect.height)
                    .offset(x: cropRect.minX, y: cropRect.minY)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true),
                        value: animation
                    )
                    .onAppear {
                        animation.toggle()
                    }
            }
        }
        .frame(width: playerSize.width, height: playerSize.height)
        .contentShape(Rectangle())
        .onAppear() {
            dragging = false
            draggedCropOffset = nil
        }
        .gesture(
            DragGesture().onChanged({ value in
                if !dragging {
                    dragging = true
                    if cropRect.contains(value.startLocation) {
                        draggedCropOffset = cropRect.origin
                    }
                }
                
                if let draggedCropOffset {
                    // drag the existing crop
                    let dragDelta = CGPoint(x: value.location.x - value.startLocation.x, y: value.location.y - value.startLocation.y)
                    let x = max(0, min(draggedCropOffset.x + dragDelta.x, playerSize.width - cropRect.width)) / playerScale
                    let y = max(0, min(draggedCropOffset.y + dragDelta.y, playerSize.height - cropRect.height)) / playerScale
                    cropOffset = CGPoint(x: floor(x), y: floor(y))
                } else {
                    // new crop rectangle
                    let minX = max(0, min(value.location.x, value.startLocation.x) / playerScale)
                    let maxX = min(playerSize.width, max(value.location.x, value.startLocation.x)) / playerScale
                    let minY = max(0, min(value.location.y, value.startLocation.y) / playerScale)
                    let maxY = min(playerSize.height, max(value.location.y, value.startLocation.y)) / playerScale
                    
                    cropOffset = CGPoint(x: floor(minX), y: floor(minY))
                    cropWidth = floor(maxX - minX)
                    cropHeight = floor(maxY - minY)
                }
            })
            .onEnded({ value in
                dragging = false
                draggedCropOffset = nil
            })
        )
    }
}
