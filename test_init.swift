import Foundation

struct Track: Identifiable, Hashable, Codable {
    var id = UUID()
    let title: String
}

var tracks: [Track] = []
for i in 0..<5 {
    tracks.append(Track(title: "\(i)"))
}
for t in tracks {
    print(t.id)
}
