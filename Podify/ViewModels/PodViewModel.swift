import SwiftUI
import Combine

enum SettingsState {
    case main
    case themes
    case sleepTimer
    case brickGame
    case musicQuiz
}

class PodViewModel: ObservableObject {
    @Published var scrollIndex: Int = 0 {
        didSet {
            let maxCount: Int
            if isCoverFlowPresented, let playlist = selectedPlaylist {
                maxCount = playlist.tracks.count
            } else if isSettingsPresented {
                switch settingsState {
                case .main: maxCount = 4
                case .themes: maxCount = ThemeFactory.presets.count + 1
                case .sleepTimer: maxCount = SleepTimerManager.shared.timerOptions.count
                case .brickGame: maxCount = 10000
                case .musicQuiz: maxCount = 5
                }
            } else {
                maxCount = currentMenu.count
            }
            
            if scrollIndex < 0 {
                scrollIndex = 0
            } else if maxCount == 0 {
                scrollIndex = 0
            } else if scrollIndex >= maxCount {
                scrollIndex = maxCount - 1
            }
        }
    }
    
    @Published var navigationPath: [String] = ["Podify"]
    @Published var currentMenu: [MenuItem] = []
    
    @Published var isShowingDocumentPicker = false
    @Published var settingsState: SettingsState = .main
    @Published var isLoading = false
    @Published var isNowPlayingPresented = false {
        didSet {
            if !isNowPlayingPresented {
                isScrubbingMode = false
            }
        }
    }
    @Published var isScrubbingMode = false
    @Published var isSettingsPresented = false
    @Published var isCoverFlowPresented = false {
        didSet {
            if isCoverFlowPresented {
                if let currentTrack = AudioEngine.shared.currentTrack,
                   let index = playbackQueue.firstIndex(where: { $0.id == currentTrack.id }) {
                    scrollIndex = index
                } else {
                    scrollIndex = 0
                }
            }
        }
    }
    @Published var selectedPlaylist: Playlist? = {
        if let data = UserDefaults.standard.data(forKey: "savedSelectedPlaylist"),
           let savedPlaylist = try? JSONDecoder().decode(Playlist.self, from: data) {
            return savedPlaylist
        }
        return nil
    }() {
        didSet {
            if let playlist = selectedPlaylist, let data = try? JSONEncoder().encode(playlist) {
                UserDefaults.standard.set(data, forKey: "savedSelectedPlaylist")
            } else {
                UserDefaults.standard.removeObject(forKey: "savedSelectedPlaylist")
            }
            if selectedPlaylist != nil {
                updatePlaybackQueue()
            }
        }
    }
    
    @Published var playbackQueue: [Track] = {
        if let data = UserDefaults.standard.data(forKey: "savedPlaybackQueue"),
           let savedQueue = try? JSONDecoder().decode([Track].self, from: data) {
            return savedQueue
        }
        return []
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(playbackQueue) {
                UserDefaults.standard.set(data, forKey: "savedPlaybackQueue")
            }
        }
    }
    
    @Published var isShuffleEnabled: Bool = UserDefaults.standard.bool(forKey: "savedShuffleState") {
        didSet {
            UserDefaults.standard.set(isShuffleEnabled, forKey: "savedShuffleState")
            AudioEngine.shared.isShuffleEnabled = isShuffleEnabled
            rebuildMainMenu()
            updatePlaybackQueue()
        }
    }
    
    private func updatePlaybackQueue() {
        guard let playlist = selectedPlaylist else {
            return
        }
        playbackQueue = isShuffleEnabled ? playlist.tracks.shuffled() : playlist.tracks
        AudioEngine.shared.updateQueue(with: playbackQueue)
    }
    
    var relinkingFolderId: UUID? = nil
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        AudioEngine.shared.isShuffleEnabled = self.isShuffleEnabled
        
        LibraryManager.shared.$syncedFolders
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.rebuildMainMenu()
                }
            }
            .store(in: &cancellables)
            
        LibraryManager.shared.$playlists
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.rebuildMainMenu()
                }
            }
            .store(in: &cancellables)
            
        AudioEngine.shared.$currentTrack
            .sink { [weak self] newTrack in
                guard let self = self, let newTrack = newTrack else { return }
                
                if self.isCoverFlowPresented {
                    let oldTrack = AudioEngine.shared.currentTrack
                    
                    if let oldTrack = oldTrack, 
                       let oldIndex = self.playbackQueue.firstIndex(where: { $0.id == oldTrack.id }) {
                        
                        if self.scrollIndex == oldIndex {
                            if let newIndex = self.playbackQueue.firstIndex(where: { $0.id == newTrack.id }) {
                                DispatchQueue.main.async {
                                    self.scrollIndex = newIndex
                                }
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func rebuildMainMenu() {
        let syncItem = MenuItem(title: "Sync Folder...", type: .folder)
        let npItem = MenuItem(title: "Now Playing", type: .folder)
        let settingsItem = MenuItem(title: "Settings", type: .folder)
        let shuffleState = isShuffleEnabled ? "On" : "Off"
        let shuffleItem = MenuItem(title: "Shuffle: " + shuffleState, type: .shuffleToggle)
        
        var newMenu = [syncItem, npItem, settingsItem, shuffleItem]
        
        for folder in LibraryManager.shared.syncedFolders {
            if folder.isBroken {
                newMenu.append(MenuItem(title: "! " + folder.displayName, type: .brokenFolder(folder)))
            } else {
                if let playlist = LibraryManager.shared.playlists.first(where: { $0.folderURL?.lastPathComponent == folder.displayName }) {
                    newMenu.append(MenuItem(title: folder.displayName, type: .playlist(playlist)))
                } else {
                    newMenu.append(MenuItem(title: folder.displayName, type: .folder))
                }
            }
        }
        
        currentMenu = newMenu
    }
    
    func handleScroll(delta: Int) {
        if isNowPlayingPresented && isScrubbingMode {
            AudioEngine.shared.seek(by: Double(delta * 5)) // scrub 5 seconds per tick
        } else {
            scrollIndex += delta
        }
    }
    
    func selectCurrentItem() {
        if isSettingsPresented {
            if settingsState == .main {
                let options: [SettingsState] = [.themes, .sleepTimer, .brickGame, .musicQuiz]
                if scrollIndex >= 0 && scrollIndex < options.count {
                    settingsState = options[scrollIndex]
                    scrollIndex = 0
                }
            } else if settingsState == .musicQuiz {
                MusicQuizManager.shared.submitAnswer(index: scrollIndex)
            }
            return
        }
        
        if isNowPlayingPresented {
            isScrubbingMode.toggle()
            return
        }
        
        if isCoverFlowPresented {
            if scrollIndex >= 0 && scrollIndex < playbackQueue.count {
                let currentTrack = playbackQueue[scrollIndex]
                AudioEngine.shared.play(track: currentTrack, in: playbackQueue)
                isNowPlayingPresented = true
            }
            return
        }
        
        guard scrollIndex >= 0 && scrollIndex < currentMenu.count else { return }
        let selected = currentMenu[scrollIndex]
        
        if selected.title == "Sync Folder..." {
            relinkingFolderId = nil
            isShowingDocumentPicker = true
        } else if selected.title == "Now Playing" {
            if AudioEngine.shared.currentTrack != nil {
                isNowPlayingPresented = true
            }
        } else if selected.title == "Settings" {
            isSettingsPresented = true
            scrollIndex = 0
        } else if case .shuffleToggle = selected.type {
            isShuffleEnabled.toggle()
        } else if case .playlist(let playlist) = selected.type {
            if selectedPlaylist?.id != playlist.id {
                selectedPlaylist = playlist
            }
            isCoverFlowPresented = true
        } else if case .brokenFolder(let folder) = selected.type {
            relinkingFolderId = folder.id
            isShowingDocumentPicker = true
        }
    }
    
    func navigateBack() {
        if isNowPlayingPresented {
            isNowPlayingPresented = false
        } else if isCoverFlowPresented {
            isCoverFlowPresented = false
            scrollIndex = 0
        } else if isSettingsPresented {
            if settingsState != .main {
                settingsState = .main
                scrollIndex = 0
            } else {
                isSettingsPresented = false
                scrollIndex = 0
            }
        }
    }
    
    func syncFolder(url: URL) {
        LibraryManager.shared.addOrUpdateFolder(from: url, relinkingId: relinkingFolderId)
        relinkingFolderId = nil
    }
}

// MARK: - Theme Engine
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let chassisColor: Color
    let backgroundColor: Color
    let accentColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let bezelColor: Color
    let wheelColor: Color
    let centerButtonColor: Color
    let fontName: String
}

struct ThemeFactory {
    static let classicMono = Theme(
        id: "classicMono",
        name: "Classic Mono",
        chassisColor: .black,
        backgroundColor: Color(red: 196/255, green: 212/255, blue: 205/255),
        accentColor: .black,
        textColor: .black,
        secondaryTextColor: Color.black.opacity(0.6),
        bezelColor: .black,
        wheelColor: Color(white: 0.9),
        centerButtonColor: Color(white: 0.8),
        fontName: "Silkscreen-Regular"
    )
    
    static let atomicGreen = Theme(
        id: "atomicGreen",
        name: "Atomic Green",
        chassisColor: Color(red: 20/255, green: 20/255, blue: 20/255),
        backgroundColor: .black,
        accentColor: Color(red: 57/255, green: 255/255, blue: 20/255),
        textColor: Color(red: 57/255, green: 255/255, blue: 20/255),
        secondaryTextColor: Color(red: 57/255, green: 255/255, blue: 20/255).opacity(0.6),
        bezelColor: Color(red: 57/255, green: 255/255, blue: 20/255),
        wheelColor: Color(white: 0.2),
        centerButtonColor: Color(white: 0.15),
        fontName: "VT323-Regular"
    )
    
    static let sunsetOrange = Theme(
        id: "sunsetOrange",
        name: "Sunset Orange",
        chassisColor: Color.white,
        backgroundColor: Color(red: 255/255, green: 240/255, blue: 200/255),
        accentColor: Color(red: 255/255, green: 100/255, blue: 50/255),
        textColor: Color(red: 100/255, green: 40/255, blue: 20/255),
        secondaryTextColor: Color(red: 100/255, green: 40/255, blue: 20/255).opacity(0.6),
        bezelColor: Color(red: 255/255, green: 150/255, blue: 50/255),
        wheelColor: Color(red: 255/255, green: 245/255, blue: 235/255),
        centerButtonColor: Color(red: 240/255, green: 230/255, blue: 220/255),
        fontName: "Silkscreen-Regular"
    )
    
    static let presets = [classicMono, atomicGreen, sunsetOrange]
}

extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme = ThemeFactory.classicMono
    
    var selectedThemeId: String {
        get { UserDefaults.standard.string(forKey: "selectedThemeId") ?? "classicMono" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedThemeId") }
    }
    
    var customChassisHex: String {
        get { UserDefaults.standard.string(forKey: "customChassisHex") ?? "000000" }
        set { UserDefaults.standard.set(newValue, forKey: "customChassisHex") }
    }
    var customBackgroundHex: String {
        get { UserDefaults.standard.string(forKey: "customBackgroundHex") ?? "FFFFFF" }
        set { UserDefaults.standard.set(newValue, forKey: "customBackgroundHex") }
    }
    var customAccentHex: String {
        get { UserDefaults.standard.string(forKey: "customAccentHex") ?? "FF0000" }
        set { UserDefaults.standard.set(newValue, forKey: "customAccentHex") }
    }
    var customTextHex: String {
        get { UserDefaults.standard.string(forKey: "customTextHex") ?? "000000" }
        set { UserDefaults.standard.set(newValue, forKey: "customTextHex") }
    }
    var customBezelHex: String {
        get { UserDefaults.standard.string(forKey: "customBezelHex") ?? "000000" }
        set { UserDefaults.standard.set(newValue, forKey: "customBezelHex") }
    }
    var customWheelHex: String {
        get { UserDefaults.standard.string(forKey: "customWheelHex") ?? "E6E6E6" }
        set { UserDefaults.standard.set(newValue, forKey: "customWheelHex") }
    }
    var customCenterButtonHex: String {
        get { UserDefaults.standard.string(forKey: "customCenterButtonHex") ?? "CCCCCC" }
        set { UserDefaults.standard.set(newValue, forKey: "customCenterButtonHex") }
    }
    
    var customChassisColor: Color {
        get { Color(hex: customChassisHex) }
        set { customChassisHex = newValue.toHex() ?? "000000"; updateCustomTheme() }
    }
    var customBackgroundColor: Color {
        get { Color(hex: customBackgroundHex) }
        set { customBackgroundHex = newValue.toHex() ?? "FFFFFF"; updateCustomTheme() }
    }
    var customAccentColor: Color {
        get { Color(hex: customAccentHex) }
        set { customAccentHex = newValue.toHex() ?? "FF0000"; updateCustomTheme() }
    }
    var customTextColor: Color {
        get { Color(hex: customTextHex) }
        set { customTextHex = newValue.toHex() ?? "000000"; updateCustomTheme() }
    }
    var customBezelColor: Color {
        get { Color(hex: customBezelHex) }
        set { customBezelHex = newValue.toHex() ?? "000000"; updateCustomTheme() }
    }
    var customWheelColor: Color {
        get { Color(hex: customWheelHex) }
        set { customWheelHex = newValue.toHex() ?? "E6E6E6"; updateCustomTheme() }
    }
    var customCenterButtonColor: Color {
        get { Color(hex: customCenterButtonHex) }
        set { customCenterButtonHex = newValue.toHex() ?? "CCCCCC"; updateCustomTheme() }
    }
    
    var activeThemeId: String {
        get { selectedThemeId }
    }
    
    init() {
        applyTheme(id: selectedThemeId)
    }
    
    func applyTheme(id: String) {
        selectedThemeId = id
        if id == "custom" {
            updateCustomTheme()
        } else if let preset = ThemeFactory.presets.first(where: { $0.id == id }) {
            currentTheme = preset
        } else {
            currentTheme = ThemeFactory.classicMono
        }
    }
    
    private func updateCustomTheme() {
        if selectedThemeId == "custom" {
            currentTheme = Theme(
                id: "custom",
                name: "Custom",
                chassisColor: customChassisColor,
                backgroundColor: customBackgroundColor,
                accentColor: customAccentColor,
                textColor: customTextColor,
                secondaryTextColor: customTextColor.opacity(0.6),
                bezelColor: customBezelColor,
                wheelColor: customWheelColor,
                centerButtonColor: customCenterButtonColor,
                fontName: "Menlo"
            )
        }
    }
}


class StatusBarManager: ObservableObject {
    @Published var currentTimeString = ""
    @Published var batteryLevel: Float = 1.0
    
    private var timer: Timer?
    
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateTime()
        updateBattery()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateTime()
            self?.updateBattery()
        }
    }
    
    private func updateTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        currentTimeString = formatter.string(from: Date())
    }
    
    private func updateBattery() {
        batteryLevel = UIDevice.current.batteryLevel
    }
    
    var batteryIcon: String {
        if batteryLevel < 0 { return "battery.100" } // Simulator usually returns -1
        if batteryLevel > 0.8 { return "battery.100" }
        if batteryLevel > 0.5 { return "battery.75" }
        if batteryLevel > 0.25 { return "battery.50" }
        return "battery.25"
    }
}

// MARK: - StatusBarView
struct StatusBarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var manager = StatusBarManager()
    
    var body: some View {
        HStack {
            Text(manager.currentTimeString)
                .font(.custom(themeManager.currentTheme.fontName, size: 10))
            
            Spacer()
            
            Image(systemName: manager.batteryIcon)
                .font(.system(size: 10))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .foregroundColor(themeManager.currentTheme.textColor)
        .background(themeManager.currentTheme.backgroundColor)
    }
}

struct CoverFlowItemView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let track: Track
    let itemWidth: CGFloat
    let isSelected: Bool
    
    @State private var artwork: UIImage? = nil
    
    private var artworkView: some View {
        Group {
            if let image = artwork {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(themeManager.currentTheme.accentColor.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(themeManager.currentTheme.accentColor)
                            .font(.largeTitle)
                    )
            }
        }
        .frame(width: itemWidth, height: itemWidth)
        .border(themeManager.currentTheme.textColor, width: isSelected ? 3 : 1)
        .clipped()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            artworkView
            
            artworkView
                .scaleEffect(y: -1)
                .mask(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 2)
        }
        .task(id: track.id) {
            artwork = nil
            if let cached = ImageCache.shared.get(for: track.id.uuidString) {
                artwork = cached
                let debug = "Track: \(track.title), ID: \(track.id), cached: YES, fileURL: \(track.fileURL?.absoluteString ?? "nil")\n"
                try? debug.appendLineToURL(fileURL: URL(fileURLWithPath: "/tmp/podify_debug.txt"))
            } else {
                artwork = await ImageCache.shared.loadAsync(for: track)
                let debug = "Track: \(track.title), ID: \(track.id), cached: NO, loaded: \(artwork != nil), fileURL: \(track.fileURL?.absoluteString ?? "nil")\n"
                try? debug.appendLineToURL(fileURL: URL(fileURLWithPath: "/tmp/podify_debug.txt"))
            }
        }
    }
}

extension String {
    func appendLineToURL(fileURL: URL) throws {
        if let data = self.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
        }
    }
}

// MARK: - CoverFlowView
struct CoverFlowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let tracks: [Track]
    let scrollIndex: Int
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let itemWidth = geometry.size.width * 0.5
                let spacing: CGFloat = -20
                let totalItemWidth = itemWidth + spacing
                
                let offset = (geometry.size.width - itemWidth) / 2 - CGFloat(scrollIndex) * totalItemWidth
                
                HStack(spacing: spacing) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        CoverFlowItemView(
                            track: track,
                            itemWidth: itemWidth,
                            isSelected: index == scrollIndex
                        )
                        .rotation3DEffect(
                            .degrees(index == scrollIndex ? 0 : (index < scrollIndex ? 45 : -45)),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .scaleEffect(index == scrollIndex ? 1.1 : 0.8)
                        .opacity(index == scrollIndex ? 1.0 : 0.6)
                        .zIndex(index == scrollIndex ? 1 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scrollIndex)
                    }
                }
                .offset(x: offset)
                .frame(maxHeight: .infinity)
            }
            
            VStack(spacing: 4) {
                if tracks.indices.contains(scrollIndex) {
                    let currentTrack = tracks[scrollIndex]
                    Text(currentTrack.title)
                        .font(.custom(themeManager.currentTheme.fontName, size: 14))
                        .bold()
                        .lineLimit(1)
                    Text(currentTrack.artist)
                        .font(.custom(themeManager.currentTheme.fontName, size: 12))
                        .lineLimit(1)
                }
            }
            .foregroundColor(themeManager.currentTheme.textColor)
            .padding(.bottom, 16)
        }
        .background(themeManager.currentTheme.backgroundColor)
        .clipped()
    }
}
