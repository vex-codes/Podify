# Podify (Podia)

An authentic iPod Classic simulator & local music player built with SwiftUI for iOS.

## Highlights

- 🎛️ **Authentic Click Wheel Navigation**: Rotational gesture tracking with haptic feedback, center select button, and physical controls (Menu, Play/Pause, Forward, Rewind).
- 📺 **Retro iPod Firmware UI**: Split-screen classic menus, authentic pixel typography (Silkscreen & VT323), and nostalgic monochrome or color LCD styling.
- 💿 **3D Cover Flow**: Interactive Cover Flow album browser with dynamic perspective transforms.
- 🎨 **Custom Themes & Wallpapers**: 25 curated retro wallpapers, custom chassis colorways, wheel colors, and LCD backlight themes.
- 🎵 **Local Audio Playback**: Import local music folders (`.mp3`, `.m4a`, `.wav`, `.flac`) via iOS Document Picker with automatic ID3 tag & embedded album artwork extraction.
- 🔊 **Full Audio Engine**: Background playback (`UIBackgroundModes: audio`), Lock Screen / Control Center Now Playing integration (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`), audio crossfade, and real-time visualizer.
- 🕹️ **Extras**: Built-in retro Brick game and configurable Sleep Timer.
- 🛡️ **Device Integrity**: Sandbox & jailbreak verification via `SecurityManager`.

## Tech Stack

- **Framework**: SwiftUI + Combine
- **Audio & Media**: AVFoundation (`AVAudioPlayer`, `AVQueuePlayer`), MediaPlayer (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`)
- **Compatibility**: iOS 17.0+ / iOS 18.0+
- **IDE**: Xcode 16+

## Project Structure

```
Podify/
├── Podia/
│   ├── Models/             # Track, MenuItem, Playlist, LibraryManager
│   ├── Services/           # AudioEngine, FileScanner, SecurityManager
│   ├── ViewModels/         # PodViewModel (state machine & navigation)
│   ├── Views/
│   │   ├── Hardware/       # IPodChassisView, ClickWheelView, DocumentPicker
│   │   └── Firmware/       # MenuView, NowPlayingView, ScreenContainer, OfflineFeatures
│   ├── Assets.xcassets/    # App icons, wallpapers, color palettes
│   ├── Fonts/              # Silkscreen & VT323 retro fonts
│   └── PodiaInfo.plist     # Background audio configuration & font registration
├── Podia.xcodeproj/        # Xcode project configuration
└── README.md
```

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/vex-codes/Podify.git
   cd Podify
   ```

2. **Open in Xcode:**
   ```bash
   open Podia.xcodeproj
   ```

3. **Run:**
   Select an iOS Simulator or connected physical iOS device and press **Cmd + R** to build and run.

4. **Import Music:**
   Use the in-app document picker on device or drag music files into the app container to scan and populate your retro library.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
