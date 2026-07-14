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
    
    private var player: AVAudioPlayer?
    private var activeQueue: [Track] = []
    private var currentIndex: Int = 0
    private var timer: Timer?
    
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
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.isMeteringEnabled = true
            player?.prepareToPlay()
            player?.play()
            
            currentTrack = track
            state = .playing
            duration = player?.duration ?? 0.0
            
            startTimer()
            updateNowPlayingInfo()
        } catch {
            print("Playback error: \\(error)")
            next()
        }
    }
    
    func togglePlayPause() {
        if state == .playing {
            player?.pause()
            state = .paused
            stopTimer()
        } else if state == .paused {
            player?.play()
            state = .playing
            startTimer()
        }
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
            player?.currentTime = 0
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.progress = player.currentTime
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        next()
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
        guard state == .playing, let player = player else { return [2, 2, 2, 2, 2] }
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
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime
        info[MPMediaItemPropertyPlaybackDuration] = player?.duration
        
        if let url = track.fileURL {
            DispatchQueue.global(qos: .background).async {
                let asset = AVAsset(url: url)
                if let image = FileScanner.shared.extractArtwork(for: asset) {
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
