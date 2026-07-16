import Foundation
import AVFoundation
import MediaPlayer
import Combine

enum PlaybackState {
    case playing, paused, stopped
}

class AudioEngine: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioEngine()
    
    @Published var state: PlaybackState = .stopped
    @Published var currentTrack: Track?
    @Published var progress: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var isShuffleEnabled: Bool = false
    @Published var isCrossfadeEnabled: Bool = false
    
    private var currentPlayer: AVAudioPlayer?
    private var fadingPlayer: AVAudioPlayer?
    private var activeQueue: [Track] = []
    private var currentIndex: Int = 0
    private var timer: Timer?
    private var isCrossfadingAutomatically = false
    
    override private init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \\(error)")
        }
    }
    
    func play(track: Track, in queue: [Track]) {
        activeQueue = queue
        activeQueue = queue
        
        if let index = activeQueue.firstIndex(where: { $0.id == track.id }) {
            currentIndex = index
            startPlayback(for: track)
        }
    }
    
    private func startPlayback(for track: Track) {
        guard let url = track.fileURL else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.volume = 0.0 // FIX: Set volume before prepareToPlay to prevent audio blast
                newPlayer.prepareToPlay()
                
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    newPlayer.delegate = self
                    newPlayer.isMeteringEnabled = true
                    
                    if self.currentPlayer != nil && self.state == .playing {
                        self.fadingPlayer?.stop()
                        self.fadingPlayer = self.currentPlayer
                        
                        self.fadingPlayer?.setVolume(0.0, fadeDuration: 8.0)
                        let playerToStop = self.fadingPlayer
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                            playerToStop?.stop()
                        }
                        
                        newPlayer.play()
                        newPlayer.setVolume(1.0, fadeDuration: 8.0)
                    } else {
                        self.currentPlayer?.stop()
                        self.fadingPlayer?.stop()
                        newPlayer.volume = 1.0
                        newPlayer.play()
                    }
                    
                    self.currentPlayer = newPlayer
                    self.currentTrack = track
                    self.state = .playing
                    self.duration = newPlayer.duration
                    self.isCrossfadingAutomatically = false
                    
                    self.startTimer()
                    self.updateNowPlayingInfo()
                }
            } catch {
                DispatchQueue.main.async {
                    print("Playback error: \(error)")
                    self?.next()
                }
            }
        }
    }
    
    func togglePlayPause() {
        if state == .playing {
            currentPlayer?.pause()
            fadingPlayer?.pause()
            state = .paused
            stopTimer()
        } else if state == .paused {
            currentPlayer?.play()
            fadingPlayer?.stop() // Abort crossfade on manual pause/resume
            state = .playing
            startTimer()
        }
        updateNowPlayingInfo()
    }
    
    func fadeOutAndPause() {
        guard let player = currentPlayer else { return }
        player.setVolume(0.0, fadeDuration: 3.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.togglePlayPause()
            player.volume = 1.0 // Reset for future playback
        }
    }
    
    func seek(by delta: TimeInterval) {
        guard let player = currentPlayer else { return }
        let newTime = player.currentTime + delta
        let clampedTime = max(0, min(newTime, duration))
        player.currentTime = clampedTime
        progress = clampedTime
        fadingPlayer?.stop()
        updateNowPlayingInfo()
    }
    
    func next() {
        guard !activeQueue.isEmpty else { return }
        currentIndex = (currentIndex + 1) % activeQueue.count
        startPlayback(for: activeQueue[currentIndex])
    }
    
    func previous() {
        guard !activeQueue.isEmpty else { return }
        if progress > 3.0 {
            currentPlayer?.currentTime = 0
            updateNowPlayingInfo()
        } else {
            currentIndex = (currentIndex - 1 + activeQueue.count) % activeQueue.count
            startPlayback(for: activeQueue[currentIndex])
        }
    }
    
    func updateQueue(with queue: [Track]) {
        activeQueue = queue
        if let current = currentTrack, let index = activeQueue.firstIndex(where: { $0.id == current.id }) {
            currentIndex = index
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.currentPlayer else { return }
            self.progress = player.currentTime
            
            let timeRemaining = player.duration - player.currentTime
            let crossfadeDuration = 8.0
            
            if self.isCrossfadeEnabled && timeRemaining <= crossfadeDuration && player.duration > crossfadeDuration * 2 && !self.isCrossfadingAutomatically && self.state == .playing {
                self.isCrossfadingAutomatically = true
                self.next()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player == currentPlayer {
            next()
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            if self?.state == .paused {
                self?.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            if self?.state == .playing {
                self?.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
    }
    

    func getMeters() -> [CGFloat] {
        guard state == .playing, let player = currentPlayer else { return [2, 2, 2, 2, 2] }
        player.updateMeters()
        
        let power = player.averagePower(forChannel: 0)
        let normalized = max(0, power + 40) / 40.0 
        
        return (0..<12).map { _ in
            let jitter = CGFloat.random(in: 0.5...1.5)
            let height = CGFloat(normalized) * 14 * jitter
            return min(14, max(2, height))
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        var info = [String: Any]()
        
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        info[MPMediaItemPropertyAlbumTitle] = track.album
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPlayer?.currentTime
        info[MPMediaItemPropertyPlaybackDuration] = currentPlayer?.duration
        
        if let url = track.fileURL {
            DispatchQueue.global(qos: .background).async {
                if let image = FileScanner.shared.extractArtwork(for: url) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    DispatchQueue.main.async {
                        info[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    }
                } else {
                    DispatchQueue.main.async {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    }
                }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}
