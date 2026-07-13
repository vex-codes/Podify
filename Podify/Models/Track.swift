import Foundation

struct Track: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let fileURL: URL?
}
