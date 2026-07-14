import Foundation

struct Track: Identifiable, Hashable, Codable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let fileURL: URL?
}

let track1 = Track(title: "A", artist: "B", album: "C", fileURL: nil)
print("Original ID: \(track1.id)")
let data = try! JSONEncoder().encode(track1)
let track2 = try! JSONDecoder().decode(Track.self, from: data)
print("Decoded ID: \(track2.id)")
