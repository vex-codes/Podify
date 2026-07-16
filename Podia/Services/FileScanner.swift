import Foundation
import AVFoundation
import UIKit

class ImageCache {
    static let shared = ImageCache()
    private let ramCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ArtworkCache_v4")
    }
    
    private init() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        ramCache.countLimit = 30 // Max 30 images in RAM
        ramCache.totalCostLimit = 1024 * 1024 * 20 // 20 MB max
    }
    
    func set(_ image: UIImage, for key: String) {
        ramCache.setObject(image, forKey: NSString(string: key))
        
        let fileURL = cacheDirectory.appendingPathComponent("\(key).jpg")
        if !fileManager.fileExists(atPath: fileURL.path) {
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL, options: .completeFileProtection)
            }
        }
    }
    
    func get(for key: String) -> UIImage? {
        if let image = ramCache.object(forKey: NSString(string: key)) {
            return image
        }
        
        let fileURL = cacheDirectory.appendingPathComponent("\(key).jpg")
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            ramCache.setObject(image, forKey: NSString(string: key))
            return image
        }
        
        return nil
    }
    
    func loadAsync(for track: Track) async -> UIImage? {
        if let image = get(for: track.id.uuidString) {
            return image
        }
        
        guard let url = track.fileURL else { return nil }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = FileScanner.shared.extractArtwork(for: url) {
                    self.set(image, for: track.id.uuidString)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

class FileScanner {
    static let shared = FileScanner()
    
    private init() {}
    
    func scanFolder(at url: URL, completion: @escaping (Playlist?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var tracks: [Track] = []
            let fileManager = FileManager.default
            
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "mp3" {
                    let asset = AVURLAsset(url: fileURL)
                    
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
            let playlistName = url.lastPathComponent
            let playlist = Playlist(title: playlistName, tracks: tracks, folderURL: url)
            
            DispatchQueue.main.async {
                completion(playlist)
            }
        }
    }
    
    private let artworkQueue = DispatchQueue(label: "com.podify.artworkQueue")
    
    func extractArtwork(for url: URL) -> UIImage? {
        return artworkQueue.sync {
            let asset = AVURLAsset(url: url)
            let metadata = asset.commonMetadata
            for item in metadata {
                if item.commonKey == .commonKeyArtwork, let data = item.dataValue {
                    return UIImage(data: data)
                }
            }
            return nil
        }
    }
}
