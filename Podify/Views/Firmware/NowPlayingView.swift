import SwiftUI
import AVFoundation

struct NowPlayingView: View {
    @ObservedObject var audioEngine = AudioEngine.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Header Bar
            HStack {
                Text("Now Playing")
                    .font(.custom("Monaco", size: 14))
                    .bold()
                Spacer()
                if audioEngine.isShuffleEnabled {
                    Image(systemName: "shuffle")
                        .font(.system(size: 10))
                }
                Image(systemName: audioEngine.state == .playing ? "play.fill" : "pause.fill")
                    .font(.system(size: 10))
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
                        .font(.custom("Monaco", size: 14))
                        .bold()
                        .lineLimit(1)
                    Text(audioEngine.currentTrack?.artist ?? "Unknown")
                        .font(.custom("Monaco", size: 12))
                        .lineLimit(1)
                    Text(audioEngine.currentTrack?.album ?? "Unknown")
                        .font(.custom("Monaco", size: 10))
                        .lineLimit(1)
                }
                .foregroundColor(themeManager.currentTheme.textColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
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
                        .font(.custom("Monaco", size: 10))
                    Spacer()
                    Text("-" + formatTime(audioEngine.duration - audioEngine.progress))
                        .font(.custom("Monaco", size: 10))
                }
                .foregroundColor(themeManager.currentTheme.textColor)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(themeManager.currentTheme.backgroundColor)
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
                Image(systemName: "music.note")
                    .foregroundColor(themeManager.currentTheme.textColor)
            }
        }
        .onAppear {
            loadArtwork()
        }
        .onChange(of: track?.id) { _, _ in
            loadArtwork()
        }
    }
    
    private func loadArtwork() {
        guard let url = track?.fileURL else {
            image = nil
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVFoundation.AVAsset(url: url)
            let art = FileScanner.shared.extractArtwork(for: asset)
            DispatchQueue.main.async {
                self.image = art
            }
        }
    }
}
