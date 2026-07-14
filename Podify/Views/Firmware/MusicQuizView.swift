import SwiftUI
import Combine

class MusicQuizManager: ObservableObject {
    static let shared = MusicQuizManager()
    
    @Published var options: [Track] = []
    @Published var correctTrack: Track? = nil
    @Published var isPlaying = false
    @Published var score = 0
    @Published var round = 1
    @Published var gameState: GameState = .idle
    @Published var selectedAnswerIndex: Int? = nil
    
    enum GameState {
        case idle
        case playing
        case answered(isCorrect: Bool)
        case finished
    }
    
    func startGame() {
        score = 0
        round = 1
        nextRound()
    }
    
    func nextRound() {
        let allTracks = LibraryManager.shared.playlists.flatMap { $0.tracks } + LibraryManager.shared.syncedFolders.flatMap { folder in
            LibraryManager.shared.playlists.first(where: { $0.folderURL?.lastPathComponent == folder.displayName })?.tracks ?? []
        }
        let uniqueTracks = Array(Set(allTracks))
        
        guard uniqueTracks.count >= 5 else {
            gameState = .finished
            return
        }
        
        options = Array(uniqueTracks.shuffled().prefix(5))
        correctTrack = options.randomElement()
        selectedAnswerIndex = nil
        gameState = .playing
        
        if let correctTrack = correctTrack {
            AudioEngine.shared.updateQueue(with: [correctTrack])
            AudioEngine.shared.play(track: correctTrack, in: [correctTrack])
            
            // Random seek if possible, but for local files it's easier to just let it play or seek slightly.
            // Let's seek 30 seconds in to skip silence.
            AudioEngine.shared.seek(by: 30) 
        }
    }
    
    func submitAnswer(index: Int) {
        guard gameState == .playing, index >= 0, index < options.count else { return }
        selectedAnswerIndex = index
        
        if options[index].id == correctTrack?.id {
            score += 1
            gameState = .answered(isCorrect: true)
        } else {
            gameState = .answered(isCorrect: false)
        }
        
        AudioEngine.shared.togglePlayPause() // Pause music
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.round >= 5 {
                self.gameState = .finished
            } else {
                self.round += 1
                self.nextRound()
            }
        }
    }
    
    func stopGame() {
        AudioEngine.shared.togglePlayPause()
        gameState = .idle
    }
}

struct MusicQuizView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: PodViewModel
    @StateObject private var quizManager = MusicQuizManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            if quizManager.gameState == .idle {
                Text("Music Quiz")
                    .font(.custom(themeManager.currentTheme.fontName, size: 16))
                    .bold()
                Text("Guess the song playing!")
                    .font(.custom(themeManager.currentTheme.fontName, size: 12))
                Text("Press Center to Start")
                    .font(.custom(themeManager.currentTheme.fontName, size: 12))
                    .padding(.top, 16)
                    .onAppear {
                        quizManager.startGame()
                    }
            } else if quizManager.gameState == .finished {
                Text("Game Over")
                    .font(.custom(themeManager.currentTheme.fontName, size: 16))
                    .bold()
                Text("Score: \(quizManager.score) / 5")
                    .font(.custom(themeManager.currentTheme.fontName, size: 14))
                    .padding(.top, 16)
            } else {
                Text("Round \(quizManager.round) - Score: \(quizManager.score)")
                    .font(.custom(themeManager.currentTheme.fontName, size: 12))
                
                if case .answered(let isCorrect) = quizManager.gameState {
                    Text(isCorrect ? "CORRECT!" : "WRONG!")
                        .font(.custom(themeManager.currentTheme.fontName, size: 16))
                        .bold()
                        .padding(.vertical, 8)
                } else {
                    HStack {
                        PixelVisualizer(color: themeManager.currentTheme.textColor, isPlaying: true)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(0..<quizManager.options.count, id: \.self) { index in
                            let isSelected = viewModel.scrollIndex == index
                            let track = quizManager.options[index]
                            
                            HStack {
                                Text(track.title)
                                    .font(.custom(themeManager.currentTheme.fontName, size: 12))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .foregroundColor(isSelected ? themeManager.currentTheme.backgroundColor : themeManager.currentTheme.textColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(isSelected ? themeManager.currentTheme.accentColor : Color.clear)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .foregroundColor(themeManager.currentTheme.textColor)
        .background(themeManager.currentTheme.backgroundColor)
        .onDisappear {
            quizManager.stopGame()
        }
    }
}
