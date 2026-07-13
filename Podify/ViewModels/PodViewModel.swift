import SwiftUI
import Combine

class PodViewModel: ObservableObject {
    @Published var scrollIndex: Int = 0 {
        didSet {
            let maxCount: Int
            if isCoverFlowPresented, let playlist = selectedPlaylist {
                maxCount = playlist.tracks.count
            } else if isSettingsPresented {
                maxCount = 4
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
    
    @Published var navigationPath: [String] = ["iPod"]
    @Published var currentMenu: [MenuItem] = []
    
    @Published var isShowingDocumentPicker = false
    @Published var isLoading = false
    @Published var isNowPlayingPresented = false
    @Published var isSettingsPresented = false
    @Published var isCoverFlowPresented = false
    @Published var selectedPlaylist: Playlist?
    @Published var isShuffleEnabled = false {
        didSet {
            rebuildMainMenu()
        }
    }
    
    var currentFolderURL: URL?
    var allTracks: [Track] = []
    
    init() {
        loadMockData()
    }
    
    func loadMockData() {
        rebuildMainMenu()
    }
    
    private func rebuildMainMenu() {
        let syncItem = MenuItem(title: "Sync Folder...", type: .folder)
        let npItem = MenuItem(title: "Now Playing", type: .folder)
        let settingsItem = MenuItem(title: "Settings", type: .folder)
        let shuffleState = isShuffleEnabled ? "On" : "Off"
        let shuffleItem = MenuItem(title: "Shuffle: " + shuffleState, type: .shuffleToggle)
        
        var newMenu = [syncItem, npItem, settingsItem, shuffleItem]
        
        for item in currentMenu {
            if case .playlist = item.type {
                newMenu.append(item)
            } else if case .track = item.type {
                newMenu.append(item)
            }
        }
        
        currentMenu = newMenu
    }
    
    func selectCurrentItem() {
        if isSettingsPresented {
            return
        }
        
        if isCoverFlowPresented {
            if let playlist = selectedPlaylist, scrollIndex >= 0 && scrollIndex < playlist.tracks.count {
                let currentTrack = playlist.tracks[scrollIndex]
                let playQueue = isShuffleEnabled ? playlist.tracks.shuffled() : playlist.tracks
                AudioEngine.shared.play(track: currentTrack, in: playQueue)
                isNowPlayingPresented = true
            }
            return
        }
        
        guard scrollIndex >= 0 && scrollIndex < currentMenu.count else { return }
        let selected = currentMenu[scrollIndex]
        
        if selected.title == "Sync Folder..." {
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
            selectedPlaylist = playlist
            isCoverFlowPresented = true
            scrollIndex = 0
        } else if case .track(let track) = selected.type {
            AudioEngine.shared.play(track: track, in: allTracks)
            isNowPlayingPresented = true
        }
    }
    
    func navigateBack() {
        if isNowPlayingPresented {
            isNowPlayingPresented = false
        } else if isCoverFlowPresented {
            isCoverFlowPresented = false
            scrollIndex = 0
        } else if isSettingsPresented {
            isSettingsPresented = false
            scrollIndex = 0
        }
    }
    
    func syncFolder(url: URL) {
        if let oldURL = currentFolderURL {
            oldURL.stopAccessingSecurityScopedResource()
        }
        currentFolderURL = url
        isLoading = true
        
        FileScanner.shared.scanFolder(at: url) { [weak self] playlist in
            guard let self = self, let playlist = playlist else { return }
            self.isLoading = false
            let syncItem = MenuItem(title: "Sync Folder...", type: .folder)
            let npItem = MenuItem(title: "Now Playing", type: .folder)
            let settingsItem = MenuItem(title: "Settings", type: .folder)
            let shuffleState = self.isShuffleEnabled ? "On" : "Off"
            let shuffleItem = MenuItem(title: "Shuffle: " + shuffleState, type: .shuffleToggle)
            
            let playlistItem = MenuItem(title: playlist.title, type: .playlist(playlist))
            
            self.allTracks = playlist.tracks
            self.currentMenu = [syncItem, npItem, settingsItem, shuffleItem, playlistItem]
            self.scrollIndex = 0
            print("Found \\(playlist.tracks.count) MP3s")
        }
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
        fontName: "Menlo"
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
        fontName: "CourierNewPS-BoldMT"
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
        fontName: "Menlo"
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

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: PodViewModel
    
    let themeOptions = ThemeFactory.presets.map { $0.id } + ["custom"]
    let themeNames = ThemeFactory.presets.map { $0.name } + ["Custom"]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.custom(themeManager.currentTheme.fontName, size: 14))
                    .bold()
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.accentColor.opacity(0.1))
            .foregroundColor(themeManager.currentTheme.textColor)
            
            Divider().background(themeManager.currentTheme.textColor)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(0..<themeOptions.count, id: \.self) { index in
                        HStack {
                            Text(themeNames[index])
                                .font(.custom(themeManager.currentTheme.fontName, size: 14))
                            Spacer()
                            if themeManager.activeThemeId == themeOptions[index] {
                                Image(systemName: "checkmark")
                            }
                        }
                        .foregroundColor(viewModel.scrollIndex == index ? themeManager.currentTheme.backgroundColor : themeManager.currentTheme.textColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(viewModel.scrollIndex == index ? themeManager.currentTheme.accentColor : Color.clear)
                    }
                    
                    if themeManager.activeThemeId == "custom" {
                        VStack(spacing: 8) {
                            ColorPicker("Chassis", selection: $themeManager.customChassisColor)
                            ColorPicker("Background", selection: $themeManager.customBackgroundColor)
                            ColorPicker("Accent", selection: $themeManager.customAccentColor)
                            ColorPicker("Text", selection: $themeManager.customTextColor)
                            ColorPicker("Bezel", selection: $themeManager.customBezelColor)
                            ColorPicker("Wheel", selection: $themeManager.customWheelColor)
                            ColorPicker("Center Btn", selection: $themeManager.customCenterButtonColor)
                        }
                        .font(.custom(themeManager.currentTheme.fontName, size: 12))
                        .foregroundColor(themeManager.currentTheme.textColor)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .background(themeManager.currentTheme.backgroundColor)
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
        
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
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
    
    var body: some View {
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
        .task(id: track.id) {
            if let cached = ImageCache.shared.get(for: track.id.uuidString) {
                artwork = cached
            } else {
                artwork = await ImageCache.shared.loadAsync(for: track)
            }
        }
    }
}

// MARK: - CoverFlowView
struct CoverFlowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let playlist: Playlist
    let scrollIndex: Int
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let itemWidth = geometry.size.width * 0.5
                let spacing: CGFloat = -20
                let totalItemWidth = itemWidth + spacing
                
                let offset = (geometry.size.width - itemWidth) / 2 - CGFloat(scrollIndex) * totalItemWidth
                
                HStack(spacing: spacing) {
                    ForEach(0..<playlist.tracks.count, id: \.self) { index in
                        let track = playlist.tracks[index]
                        
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
                if playlist.tracks.indices.contains(scrollIndex) {
                    let currentTrack = playlist.tracks[scrollIndex]
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
