import SwiftUI
import Combine

// MARK: - Sleep Timer Manager
class SleepTimerManager: ObservableObject {
    static let shared = SleepTimerManager()
    
    @Published var remainingMinutes: Int = 0
    @Published var isActive = false
    private var timer: Timer?
    
    let timerOptions = [0, 15, 30, 45, 60, 90, 120]
    
    func toggleTimer(index: Int) {
        if index >= 0 && index < timerOptions.count {
            let selected = timerOptions[index]
            if selected == 0 {
                cancelTimer()
            } else {
                startTimer(minutes: selected)
            }
        }
    }
    
    func startTimer(minutes: Int) {
        remainingMinutes = minutes * 60 // Wait, actually it's seconds, but let's just use it as minutes variable for simplicity. I'll just store seconds.
        remainingSeconds = minutes * 60
        isActive = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                } else {
                    self.cancelTimer()
                    if AudioEngine.shared.state == .playing {
                        AudioEngine.shared.togglePlayPause()
                    }
                }
            }
        }
    }
    
    @Published var remainingSeconds: Int = 0
    
    func cancelTimer() {
        isActive = false
        remainingSeconds = 0
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Brick Game Engine
struct Brick {
    var rect: CGRect
    var isBroken: Bool = false
}

class BrickGameEngine: ObservableObject {
    @Published var ballPos = CGPoint(x: 100, y: 120)
    @Published var paddlePos: CGFloat = 80
    @Published var bricks: [Brick] = []
    
    var ballVelocity = CGPoint(x: 2.5, y: -2.5)
    let ballSize: CGFloat = 6
    let paddleWidth: CGFloat = 40
    let paddleHeight: CGFloat = 6
    
    // Dynamic screen resolution
    var gameWidth: CGFloat = 220
    var gameHeight: CGFloat = 160
    
    var lastScrollIndex = 0
    private var displayLink: CADisplayLink?
    
    func startGame() {
        ballPos = CGPoint(x: gameWidth / 2, y: gameHeight / 2)
        paddlePos = (gameWidth - paddleWidth) / 2
        ballVelocity = CGPoint(x: 2.5, y: -2.5)
        
        bricks = []
        let cols = 5
        let rows = 4
        let bWidth: CGFloat = (gameWidth - 20) / CGFloat(cols) - 4
        let bHeight: CGFloat = 12
        let padding: CGFloat = 4
        let startX: CGFloat = 10
        for r in 0..<rows {
            for c in 0..<cols {
                let rect = CGRect(
                    x: startX + CGFloat(c) * (bWidth + padding),
                    y: 20 + CGFloat(r) * (bHeight + padding),
                    width: bWidth,
                    height: bHeight
                )
                bricks.append(Brick(rect: rect))
            }
        }
        
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopGame() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func movePaddle(delta: Int) {
        paddlePos += CGFloat(delta * 12)
        paddlePos = max(0, min(gameWidth - paddleWidth, paddlePos))
    }
    
    @objc func update() {
        ballPos.x += ballVelocity.x
        ballPos.y += ballVelocity.y
        
        if ballPos.x <= 0 || ballPos.x + ballSize >= gameWidth {
            ballVelocity.x *= -1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        if ballPos.y <= 0 {
            ballVelocity.y *= -1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        if ballPos.y > gameHeight + 10 {
            startGame() 
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            return
        }
        
        let paddleRect = CGRect(x: paddlePos, y: gameHeight - paddleHeight, width: paddleWidth, height: paddleHeight)
        let ballRect = CGRect(x: ballPos.x, y: ballPos.y, width: ballSize, height: ballSize)
        
        if ballRect.intersects(paddleRect) && ballVelocity.y > 0 {
            ballVelocity.y *= -1
            let hitFactor = (ballPos.x - (paddlePos + paddleWidth/2)) / (paddleWidth/2)
            ballVelocity.x = hitFactor * 3.0
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        for i in 0..<bricks.count {
            if !bricks[i].isBroken && ballRect.intersects(bricks[i].rect) {
                bricks[i].isBroken = true
                ballVelocity.y *= -1
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                break 
            }
        }
    }
}

// MARK: - Brick Game View
struct BrickGameView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: PodViewModel
    @StateObject private var engine = BrickGameEngine()
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let ballRect = CGRect(x: engine.ballPos.x, y: engine.ballPos.y, width: engine.ballSize, height: engine.ballSize)
                context.fill(Path(ellipseIn: ballRect), with: .color(themeManager.currentTheme.textColor))
                
                let paddleRect = CGRect(x: engine.paddlePos, y: engine.gameHeight - engine.paddleHeight, width: engine.paddleWidth, height: engine.paddleHeight)
                context.fill(Path(paddleRect), with: .color(themeManager.currentTheme.textColor))
                
                for brick in engine.bricks {
                    if !brick.isBroken {
                        let rect = CGRect(x: brick.rect.minX + 1, y: brick.rect.minY + 1, width: brick.rect.width - 2, height: brick.rect.height - 2)
                        context.fill(Path(rect), with: .color(themeManager.currentTheme.textColor))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                engine.gameWidth = geo.size.width
                engine.gameHeight = geo.size.height
                engine.lastScrollIndex = viewModel.scrollIndex
                engine.startGame()
            }
        }
        .onDisappear {
            engine.stopGame()
        }
        .onChange(of: viewModel.scrollIndex) { oldIndex, newIndex in
            engine.movePaddle(delta: newIndex > engine.lastScrollIndex ? 1 : -1)
            engine.lastScrollIndex = newIndex
        }
    }
}

// MARK: - Sleep Timer View
struct SleepTimerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: PodViewModel
    @ObservedObject var sleepTimer = SleepTimerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if sleepTimer.isActive {
                HStack {
                    Image(systemName: "timer")
                    Text(String(format: "%02d:%02d", sleepTimer.remainingSeconds / 60, sleepTimer.remainingSeconds % 60))
                        .font(.custom(themeManager.currentTheme.fontName, size: 16))
                        .bold()
                }
                .foregroundColor(themeManager.currentTheme.textColor)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(themeManager.currentTheme.accentColor.opacity(0.1))
                
                Divider().background(themeManager.currentTheme.textColor)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(0..<sleepTimer.timerOptions.count, id: \.self) { index in
                        let option = sleepTimer.timerOptions[index]
                        HStack {
                            Text(option == 0 ? "Off" : "\(option) Minutes")
                                .font(.custom(themeManager.currentTheme.fontName, size: 14))
                            Spacer()
                            if (sleepTimer.isActive && option == sleepTimer.remainingSeconds / 60) || (!sleepTimer.isActive && option == 0) {
                                Image(systemName: "checkmark")
                            }
                        }
                        .foregroundColor(viewModel.scrollIndex == index ? themeManager.currentTheme.backgroundColor : themeManager.currentTheme.textColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(viewModel.scrollIndex == index ? themeManager.currentTheme.accentColor : Color.clear)
                    }
                }
            }
        }
    }
}

// MARK: - Settings Themes View
struct SettingsThemesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: PodViewModel
    
    let themeOptions = ThemeFactory.presets.map { $0.id } + ["custom"]
    let themeNames = ThemeFactory.presets.map { $0.name } + ["Custom"]
    
    var body: some View {
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
                        
                        Picker("Font", selection: $themeManager.customFontName) {
                            Text("Menlo").tag("Menlo")
                            Text("Silkscreen").tag("Silkscreen")
                            Text("VT323").tag("VT323")
                        }
                        .pickerStyle(.menu)
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
}

// MARK: - Settings Main View
struct SettingsMainView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: PodViewModel
    let options = ["Themes", "Sleep Timer", "Brick Game"]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<options.count, id: \.self) { index in
                    HStack {
                        Text(options[index])
                            .font(.custom(themeManager.currentTheme.fontName, size: 14))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(viewModel.scrollIndex == index ? themeManager.currentTheme.backgroundColor : themeManager.currentTheme.textColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(viewModel.scrollIndex == index ? themeManager.currentTheme.accentColor : Color.clear)
                }
            }
        }
    }
}

// MARK: - Settings View (Router)
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: PodViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(headerTitle)
                    .font(.custom(themeManager.currentTheme.fontName, size: 14))
                    .bold()
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.accentColor.opacity(0.1))
            .foregroundColor(themeManager.currentTheme.textColor)
            
            Divider().background(themeManager.currentTheme.textColor)
            
            if viewModel.settingsState == .main {
                SettingsMainView(viewModel: viewModel)
            } else if viewModel.settingsState == .themes {
                SettingsThemesView(viewModel: viewModel)
            } else if viewModel.settingsState == .sleepTimer {
                SleepTimerView(viewModel: viewModel)
            } else if viewModel.settingsState == .brickGame {
                BrickGameView(viewModel: viewModel)
            }
        }
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    var headerTitle: String {
        switch viewModel.settingsState {
        case .main: return "Settings"
        case .themes: return "Themes"
        case .sleepTimer: return "Sleep Timer"
        case .brickGame: return "Brick Game"
        }
    }
}
