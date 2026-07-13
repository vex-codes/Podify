import Foundation
import AVFoundation
import UIKit

class FileScanner {
    static let shared = FileScanner()
    
    private init() {}
    
    func scanFolder(at url: URL, completion: @escaping ([Track]) -> Void) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security scoped resource.")
            completion([])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var tracks: [Track] = []
            let fileManager = FileManager.default
            
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else {
                url.stopAccessingSecurityScopedResource()
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "mp3" {
                    let asset = AVAsset(url: fileURL)
                    
                    var title = fileURL.deletingPathExtension().lastPathComponent
                    var artist = "Unknown Artist"
                    var album = "Unknown Album"
                    
                    let metadata = asset.commonMetadata
                    for item in metadata {
                        guard let key = item.commonKey?.rawValue, let value = item.value else { continue }
                        
                        switch key {
                        case AVMetadataKey.commonKeyTitle.rawValue:
                            title = value as? String ?? title
                        case AVMetadataKey.commonKeyArtist.rawValue:
                            artist = value as? String ?? artist
                        case AVMetadataKey.commonKeyAlbumName.rawValue:
                            album = value as? String ?? album
                        default:
                            break
                        }
                    }
                    
                    let track = Track(title: title, artist: artist, album: album, fileURL: fileURL)
                    tracks.append(track)
                }
            }
            
            tracks.sort { $0.title < $1.title }
            
            DispatchQueue.main.async {
                completion(tracks)
            }
        }
    }
    
    func extractArtwork(for asset: AVAsset) -> UIImage? {
        let metadata = asset.commonMetadata
        for item in metadata {
            if item.commonKey == .commonKeyArtwork, let data = item.dataValue {
                return UIImage(data: data)
            }
        }
        return nil
    }
}
