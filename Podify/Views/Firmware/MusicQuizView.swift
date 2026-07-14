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
    @Published var timeRemaining = 5
    var timer: Timer?
    
    enum GameState: Equatable {
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
        timer?.invalidate()
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
        timeRemaining = 5
        gameState = .playing
        
        if let correctTrack = correctTrack {
            AudioEngine.shared.updateQueue(with: [correctTrack])
            AudioEngine.shared.play(track: correctTrack, in: [correctTrack])
            AudioEngine.shared.seek(by: 30) 
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.timeRemaining > 0 {
                        self.timeRemaining -= 1
                    } else {
                        self.timer?.invalidate()
                        if AudioEngine.shared.state == .playing {
                            AudioEngine.shared.togglePlayPause()
                        }
                    }
                }
            }
        }
    }
    
    func submitAnswer(index: Int) {
        guard gameState == .playing, index >= 0, index < options.count else { return }
        timer?.invalidate()
        selectedAnswerIndex = index
        
        if options[index].id == correctTrack?.id {
            score += 1
            gameState = .answered(isCorrect: true)
        } else {
            gameState = .answered(isCorrect: false)
        }
        
        if AudioEngine.shared.state == .playing {
            AudioEngine.shared.togglePlayPause() // Pause music
        }
        
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
        timer?.invalidate()
        if AudioEngine.shared.state == .playing {
            AudioEngine.shared.togglePlayPause()
        }
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
                        Text("0:0\(quizManager.timeRemaining)")
                            .font(.custom(themeManager.currentTheme.fontName, size: 12))
                    }
                    .padding(.horizontal, 16)
                }
                
                GeometryReader { geometry in
                    let itemWidth = geometry.size.width * 0.45
                    let spacing: CGFloat = -20
                    let totalItemWidth = itemWidth + spacing
                    let offset = (geometry.size.width - itemWidth) / 2 - CGFloat(viewModel.scrollIndex) * totalItemWidth
                    
                    HStack(spacing: spacing) {
                        ForEach(Array(quizManager.options.enumerated()), id: \.element.id) { index, track in
                            CoverFlowItemView(
                                track: track,
                                itemWidth: itemWidth,
                                isSelected: index == viewModel.scrollIndex,
                                showReflection: false
                            )
                            .rotation3DEffect(
                                .degrees(index == viewModel.scrollIndex ? 0 : (index < viewModel.scrollIndex ? 45 : -45)),
                                axis: (x: 0, y: 1, z: 0)
                            )
                            .scaleEffect(index == viewModel.scrollIndex ? 1.05 : 0.75)
                            .opacity(index == viewModel.scrollIndex ? 1.0 : 0.6)
                            .zIndex(index == viewModel.scrollIndex ? 1 : 0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.scrollIndex)
                        }
                    }
                    .offset(x: offset)
                    .frame(maxHeight: .infinity)
                }
                
                VStack(spacing: 2) {
                    if quizManager.options.indices.contains(viewModel.scrollIndex) {
                        let selected = quizManager.options[viewModel.scrollIndex]
                        Text(selected.title)
                            .font(.custom(themeManager.currentTheme.fontName, size: 14))
                            .bold()
                            .lineLimit(1)
                        Text(selected.artist)
                            .font(.custom(themeManager.currentTheme.fontName, size: 10))
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, 8)
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
