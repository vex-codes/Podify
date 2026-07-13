import SwiftUI
import Combine

class PodViewModel: ObservableObject {
    @Published var scrollIndex: Int = 0 {
        didSet {
            if scrollIndex < 0 {
                scrollIndex = 0
            } else if scrollIndex >= currentMenu.count {
                scrollIndex = max(0, currentMenu.count - 1)
            }
        }
    }
    
    @Published var navigationPath: [String] = ["iPod"]
    @Published var currentMenu: [MenuItem] = []
    
    @Published var isShowingDocumentPicker = false
    @Published var isLoading = false
    @Published var isNowPlayingPresented = false
    
    var currentFolderURL: URL?
    var allTracks: [Track] = []
    
    init() {
        loadMockData()
    }
    
    func loadMockData() {
        let syncItem = MenuItem(title: "Sync Folder...", type: .folder)
        let npItem = MenuItem(title: "Now Playing", type: .folder)
        
        let tracks = [
            Track(title: "Body So Tea", artist: "Coco Jones", album: "R&B Now", fileURL: nil),
            Track(title: "Get Lucky", artist: "Daft Punk", album: "Random Access Memories", fileURL: nil)
        ]
        
        allTracks = tracks
        currentMenu = [syncItem, npItem] + tracks.map { MenuItem(title: $0.title, type: .track($0)) }
    }
    
    func selectCurrentItem() {
        guard scrollIndex >= 0 && scrollIndex < currentMenu.count else { return }
        let selected = currentMenu[scrollIndex]
        
        if selected.title == "Sync Folder..." {
            isShowingDocumentPicker = true
        } else if selected.title == "Now Playing" {
            if AudioEngine.shared.currentTrack != nil {
                isNowPlayingPresented = true
            }
        } else if case .track(let track) = selected.type {
            AudioEngine.shared.play(track: track, in: allTracks)
            isNowPlayingPresented = true
        }
    }
    
    func navigateBack() {
        if isNowPlayingPresented {
            isNowPlayingPresented = false
        }
    }
    
    func syncFolder(url: URL) {
        if let oldURL = currentFolderURL {
            oldURL.stopAccessingSecurityScopedResource()
        }
        currentFolderURL = url
        isLoading = true
        
        FileScanner.shared.scanFolder(at: url) { [weak self] tracks in
            guard let self = self else { return }
            self.isLoading = false
            let syncItem = MenuItem(title: "Sync Folder...", type: .folder)
            let npItem = MenuItem(title: "Now Playing", type: .folder)
            let trackItems = tracks.map { MenuItem(title: $0.title, type: .track($0)) }
            self.allTracks = tracks
            self.currentMenu = [syncItem, npItem] + trackItems
            self.scrollIndex = 0
            print("Found \\(tracks.count) MP3s")
        }
    }
}
