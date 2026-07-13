import SwiftUI
import Combine

class PodViewModel: ObservableObject {
    @Published var scrollIndex: Int = 0 {
        didSet {
            let maxCount = isSettingsPresented ? 4 : currentMenu.count
            if scrollIndex < 0 {
                scrollIndex = 0
            } else if scrollIndex >= maxCount {
                scrollIndex = max(0, maxCount - 1)
            }
        }
    }
    
    @Published var navigationPath: [String] = ["iPod"]
    @Published var currentMenu: [MenuItem] = []
    
    @Published var isShowingDocumentPicker = false
    @Published var isLoading = false
    @Published var isNowPlayingPresented = false
    @Published var isSettingsPresented = false
    
    var currentFolderURL: URL?
    var allTracks: [Track] = []
    
    init() {
        loadMockData()
    }
    
    func loadMockData() {
        let syncItem = MenuItem(title: "Sync Folder...", type: .folder)
        let npItem = MenuItem(title: "Now Playing", type: .folder)
        let settingsItem = MenuItem(title: "Settings", type: .folder)
        
        let tracks = [
            Track(title: "Body So Tea", artist: "Coco Jones", album: "R&B Now", fileURL: nil),
            Track(title: "Get Lucky", artist: "Daft Punk", album: "Random Access Memories", fileURL: nil)
        ]
        
        allTracks = tracks
        currentMenu = [syncItem, npItem, settingsItem] + tracks.map { MenuItem(title: $0.title, type: .track($0)) }
    }
    
    func selectCurrentItem() {
        if isSettingsPresented {
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
        } else if case .track(let track) = selected.type {
            AudioEngine.shared.play(track: track, in: allTracks)
            isNowPlayingPresented = true
        }
    }
    
    func navigateBack() {
        if isNowPlayingPresented {
            isNowPlayingPresented = false
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
        
        FileScanner.shared.scanFolder(at: url) { [weak self] tracks in
            guard let self = self else { return }
            self.isLoading = false
            let syncItem = MenuItem(title: "Sync Folder...", type: .folder)
            let npItem = MenuItem(title: "Now Playing", type: .folder)
            let settingsItem = MenuItem(title: "Settings", type: .folder)
            let trackItems = tracks.map { MenuItem(title: $0.title, type: .track($0)) }
            self.allTracks = tracks
            self.currentMenu = [syncItem, npItem, settingsItem] + trackItems
            self.scrollIndex = 0
            print("Found \\(tracks.count) MP3s")
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
    let bezelColor: Color
    let wheelColor: Color
    let centerButtonColor: Color
}

struct ThemeFactory {
    static let classicMono = Theme(
        id: "classicMono",
        name: "Classic Mono",
        chassisColor: .black,
        backgroundColor: Color(red: 196/255, green: 212/255, blue: 205/255),
        accentColor: .black,
        textColor: .black,
        bezelColor: .black,
        wheelColor: Color(white: 0.9),
        centerButtonColor: Color(white: 0.8)
    )
    
    static let atomicGreen = Theme(
        id: "atomicGreen",
        name: "Atomic Green",
        chassisColor: Color(red: 20/255, green: 20/255, blue: 20/255),
        backgroundColor: .black,
        accentColor: Color(red: 57/255, green: 255/255, blue: 20/255),
        textColor: Color(red: 57/255, green: 255/255, blue: 20/255),
        bezelColor: Color(red: 57/255, green: 255/255, blue: 20/255),
        wheelColor: Color(white: 0.2),
        centerButtonColor: Color(white: 0.15)
    )
    
    static let sunsetOrange = Theme(
        id: "sunsetOrange",
        name: "Sunset Orange",
        chassisColor: Color.white,
        backgroundColor: Color(red: 255/255, green: 240/255, blue: 200/255),
        accentColor: Color(red: 255/255, green: 100/255, blue: 50/255),
        textColor: Color(red: 100/255, green: 40/255, blue: 20/255),
        bezelColor: Color(red: 255/255, green: 150/255, blue: 50/255),
        wheelColor: Color(red: 255/255, green: 245/255, blue: 235/255),
        centerButtonColor: Color(red: 240/255, green: 230/255, blue: 220/255)
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
                bezelColor: customBezelColor,
                wheelColor: customWheelColor,
                centerButtonColor: customCenterButtonColor
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
                    .font(.custom("Monaco", size: 14))
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
                                .font(.custom("Monaco", size: 14))
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
                        .font(.custom("Monaco", size: 12))
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
