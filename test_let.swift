import Foundation

struct Track: Identifiable, Hashable, Codable {
    let id = UUID()
    let title: String
}

let track1 = Track(title: "A")
let data = try! JSONEncoder().encode(track1)
print("JSON: \(String(data: data, encoding: .utf8)!)")
