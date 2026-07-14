import Foundation

struct Track: Identifiable, Hashable, Codable {
    var id = UUID()
    let title: String
    let artist: String
    let album: String
    let fileURL: URL?
}

let track1 = Track(title: "A", artist: "B", album: "C", fileURL: URL(string: "file:///path/to/A"))
let data = try! JSONEncoder().encode(track1)
print("JSON: \(String(data: data, encoding: .utf8)!)")
let track2 = try! JSONDecoder().decode(Track.self, from: data)
print("Decoded ID: \(track2.id)")
