import Foundation

struct Track: Identifiable, Hashable, Codable {
    let id = UUID()
    let title: String
}

let json = """
[{"title": "A"}, {"title": "B"}, {"title": "C"}]
"""

let tracks = try! JSONDecoder().decode([Track].self, from: json.data(using: .utf8)!)
for t in tracks {
    print(t.id)
}
