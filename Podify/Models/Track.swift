import Foundation

struct Track: Identifiable, Hashable, Codable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let fileURL: URL?
}

struct Playlist: Identifiable, Hashable, Codable {
    let id = UUID()
    let title: String
    let tracks: [Track]
    let folderURL: URL?
    
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
