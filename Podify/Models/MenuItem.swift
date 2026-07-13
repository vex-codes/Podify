import Foundation

enum MenuItemType {
    case folder
    case playlist
    case track(Track)
    case back
}

struct MenuItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let type: MenuItemType
    
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
