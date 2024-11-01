//
//  FilePicker.swift
//  Spatial Thumbnail
//
//  Created by Anthony Maës (Acute Immersive) on 10/29/24.
//

import SwiftUI

/// A button revealing a file importer configured to only allow the selection of videos.
public struct FilePicker: View {
    /// The visibility of the file importer.
    @State private var isFileImporterShowing = false
    
    /// The callback to execute after a file has been picked.
    var handler: (URL, Bool) -> Void
    
    public var body: some View {
        Button("Open from Files", systemImage: "folder.fill") {
            isFileImporterShowing.toggle()
        }
        .fileImporter(
            isPresented: $isFileImporterShowing,
            allowedContentTypes: [.audiovisualContent]
        ) { result in
            switch result {
            case .success(let url):
                handler(url, url.startAccessingSecurityScopedResource())
                break
                
            case .failure(let error):
                print("Error: failed to load file: \(error)")
                break
            }
        }
    }
}

#Preview {
    FilePicker() { _, _ in
        // nothing
    }
}
