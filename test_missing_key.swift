import Foundation

struct Track: Identifiable, Hashable, Codable {
    var id = UUID()
    let title: String
}

let json = """
[{"title": "A"}, {"title": "B"}, {"title": "C"}]
"""

do {
    let tracks = try JSONDecoder().decode([Track].self, from: json.data(using: .utf8)!)
    for t in tracks {
        print(t.id)
    }
} catch {
    print("Error: \(error)")
}
