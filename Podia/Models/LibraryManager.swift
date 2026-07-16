import Foundation
import Combine

struct SyncedFolder: Codable, Identifiable {
    var id: UUID = UUID()
    var displayName: String
    var bookmarkData: Data
    var isBroken: Bool = false
    
    // Non-codable, runtime resolved URL
    var resolvedURL: URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}

class LibraryManager: ObservableObject {
    static let shared = LibraryManager()
    
    @Published var syncedFolders: [SyncedFolder] = []
    @Published var playlists: [Playlist] = [] // Contains active playlists loaded from non-broken folders
    
    private let userDefaultsKey = "SyncedFolders"
    
    private init() {
        loadFolders()
    }
    
    func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let folders = try? JSONDecoder().decode([SyncedFolder].self, from: data) else {
            return
        }
        
        var loadedFolders = folders
        
        for i in 0..<loadedFolders.count {
            if let url = loadedFolders[i].resolvedURL {
                let accessGranted = url.startAccessingSecurityScopedResource()
                loadedFolders[i].isBroken = !accessGranted
            } else {
                loadedFolders[i].isBroken = true
            }
        }
        
        self.syncedFolders = loadedFolders
        saveFolders()
        autoSync()
    }
    
    func saveFolders() {
        if let data = try? JSONEncoder().encode(syncedFolders) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func addOrUpdateFolder(from url: URL, relinkingId: UUID? = nil) {
        guard url.startAccessingSecurityScopedResource() else { return }
        
        do {
            let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            let displayName = url.lastPathComponent
            
            if let relinkingId = relinkingId {
                if let index = syncedFolders.firstIndex(where: { $0.id == relinkingId }) {
                    syncedFolders[index].bookmarkData = bookmark
                    syncedFolders[index].displayName = displayName
                    syncedFolders[index].isBroken = false
                }
            } else {
                let isDuplicate = syncedFolders.contains { existingFolder in
                    if let existingURL = existingFolder.resolvedURL {
                        return existingURL.path.lowercased() == url.path.lowercased()
                    }
                    return existingFolder.bookmarkData == bookmark
                }
                
                if !isDuplicate {
                    let newFolder = SyncedFolder(displayName: displayName, bookmarkData: bookmark, isBroken: false)
                    syncedFolders.append(newFolder)
                } else {
                    return
                }
            }
            
            saveFolders()
            autoSync()
        } catch {
            print("Failed to create bookmark: \\(error)")
        }
    }
    
    func removeFolder(id: UUID) {
        if let folder = syncedFolders.first(where: { $0.id == id }), let url = folder.resolvedURL {
            url.stopAccessingSecurityScopedResource()
        }
        syncedFolders.removeAll { $0.id == id }
        saveFolders()
        autoSync()
    }
    
    func autoSync() {
        var newPlaylists: [Playlist] = []
        let dispatchGroup = DispatchGroup()
        
        for folder in syncedFolders where !folder.isBroken {
            if let url = folder.resolvedURL {
                dispatchGroup.enter()
                FileScanner.shared.scanFolder(at: url) { playlist in
                    if let playlist = playlist {
                        newPlaylists.append(playlist)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.playlists = newPlaylists.sorted { $0.title < $1.title }
        }
    }
}
