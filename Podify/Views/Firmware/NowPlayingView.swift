import SwiftUI
import AVFoundation
import Combine

struct NowPlayingView: View {
    @ObservedObject var audioEngine = AudioEngine.shared
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 12) {
            // Header Bar
            HStack {
                Text("Now Playing")
                    .font(.custom(themeManager.currentTheme.fontName, size: 14))
                    .bold()
                Spacer()
                if audioEngine.isShuffleEnabled {
                    Text("SHUFFLE")
                        .font(.custom(themeManager.currentTheme.fontName, size: 10))
                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                }
                Text(audioEngine.state == .playing ? "▶︎" : "||")
                    .font(.custom(themeManager.currentTheme.fontName, size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.accentColor.opacity(0.1))
            .foregroundColor(themeManager.currentTheme.textColor)
            
            Divider().background(themeManager.currentTheme.textColor)
            
            HStack(spacing: 16) {
                // Artwork Placeholder
                Rectangle()
                    .fill(themeManager.currentTheme.textColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        ArtworkView(track: audioEngine.currentTrack)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioEngine.currentTrack?.title ?? "Unknown")
                        .font(.custom(themeManager.currentTheme.fontName, size: 14))
                        .bold()
                        .lineLimit(1)
                    Text(audioEngine.currentTrack?.artist ?? "Unknown")
                        .font(.custom(themeManager.currentTheme.fontName, size: 12))
                        .lineLimit(1)
                    Text(audioEngine.currentTrack?.album ?? "Unknown")
                        .font(.custom(themeManager.currentTheme.fontName, size: 10))
                        .lineLimit(1)
                }
                .foregroundColor(themeManager.currentTheme.textColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            HStack(alignment: .bottom) {
                Text("(^_^)")
                    .font(.custom(themeManager.currentTheme.fontName, size: 14))
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                Spacer()
                PixelVisualizer(color: themeManager.currentTheme.textColor, isPlaying: audioEngine.state == .playing)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, -4)
            
            // Progress Bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(themeManager.currentTheme.textColor.opacity(0.2))
                            .frame(height: 10)
                        
                        Rectangle()
                            .fill(themeManager.currentTheme.textColor)
                            .frame(width: max(0, geo.size.width * CGFloat(audioEngine.progress / max(1, audioEngine.duration))), height: 10)
                    }
                }
                .frame(height: 10)
                
                HStack {
                    Text(formatTime(audioEngine.progress))
                        .font(.custom(themeManager.currentTheme.fontName, size: 10))
                    Spacer()
                    Text("-" + formatTime(audioEngine.duration - audioEngine.progress))
                        .font(.custom(themeManager.currentTheme.fontName, size: 10))
                }
                .foregroundColor(themeManager.currentTheme.textColor)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(themeManager.currentTheme.backgroundColor)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            let current = audioEngine.currentTrack
            audioEngine.currentTrack = current
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                let current = audioEngine.currentTrack
                audioEngine.currentTrack = current
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time > 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ArtworkView: View {
    let track: Track?
    @State private var image: UIImage?
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
        .task(id: track?.id) {
            guard let track = track else {
                image = nil
                return
            }
            if let cached = ImageCache.shared.get(for: track.id.uuidString) {
                image = cached
            } else {
                image = await ImageCache.shared.loadAsync(for: track)
            }
        }
    }
}

struct PixelVisualizer: View {
    var color: Color
    var isPlaying: Bool
    
    @State private var heights: [CGFloat] = Array(repeating: 2, count: 12)
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<12, id: \.self) { index in
                Rectangle()
                    .fill(color)
                    .frame(width: 4, height: isPlaying ? heights[index] : 2)
                    .animation(.linear(duration: 0.15), value: heights)
            }
        }
        .frame(height: 14, alignment: .bottom)
        .onReceive(timer) { _ in
            if isPlaying {
                heights = AudioEngine.shared.getMeters()
            }
        }
    }
}
