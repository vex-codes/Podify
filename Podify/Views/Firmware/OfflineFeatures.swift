import SwiftUI
import Combine

// MARK: - Theme Background View
struct ThemeBackgroundView: View {
    @EnvironmentObject var themeManager: ThemeManager
    var isCoverFlow: Bool = false
    
    var body: some View {
        Group {
            if themeManager.activeThemeId == "custom", let bg = themeManager.currentTheme.backgroundImage {
                GeometryReader { geo in
                    Image(bg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(isCoverFlow ? 0.3 : 1.0)
                        .clipped()
                }
                .clipped()
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Shadow Modifier
extension View {
    @ViewBuilder
    func applyThemeShadow(themeManager: ThemeManager) -> some View {
        if themeManager.activeThemeId == "custom", themeManager.currentTheme.backgroundImage != nil {
            self.shadow(color: themeManager.currentTheme.backgroundColor.opacity(0.8), radius: 2, x: 1, y: 1)
        } else {
            self
        }
    }
}

// MARK: - Sleep Timer Manager
enum TimerStage {
    case hours
    case minutes
    case seconds
    case running
}

class SleepTimerManager: ObservableObject {
    static let shared = SleepTimerManager()
    
    @Published var stage: TimerStage = .hours
    @Published var selectedHours = 0
    @Published var selectedMinutes = 0
    @Published var selectedSeconds = 0
    
    @Published var remainingSeconds: Int = 0
    @Published var isActive = false
    private var timer: Timer?
    
    func advanceStage(scrollIndex: Int) {
        switch stage {
        case .hours:
            selectedHours = scrollIndex
            stage = .minutes
        case .minutes:
            selectedMinutes = scrollIndex
            stage = .seconds
        case .seconds:
            selectedSeconds = scrollIndex
            stage = .running
            startTimer()
        case .running:
            cancelTimer()
        }
    }
    
    func startTimer() {
        remainingSeconds = (selectedHours * 3600) + (selectedMinutes * 60) + selectedSeconds
        
        if remainingSeconds == 0 {
            cancelTimer()
            return
        }
        
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
                        AudioEngine.shared.fadeOutAndPause()
                    }
                }
            }
        }
    }
    
    func cancelTimer() {
        isActive = false
        stage = .hours
        remainingSeconds = 0
        selectedHours = 0
        selectedMinutes = 0
        selectedSeconds = 0
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
    enum GameState {
        case playing
        case won
    }
    
    @Published var gameState: GameState = .playing
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
        gameState = .playing
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
                
                if bricks.allSatisfy({ $0.isBroken }) {
                    gameState = .won
                    stopGame()
                }
                
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
            Group {
                if engine.gameState == .won {
                    VStack {
                        Spacer()
                        Text("YOU WIN!")
                            .font(.custom(themeManager.currentTheme.fontName, size: 24))
                            .foregroundColor(themeManager.currentTheme.textColor)
                            .bold()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
                }
            }
            .applyThemeShadow(themeManager: themeManager)
            .background(ThemeBackgroundView())
            .onAppear {
                engine.gameWidth = geo.size.width
                engine.gameHeight = geo.size.height
                engine.lastScrollIndex = viewModel.scrollIndex
                engine.startGame()
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
}

// MARK: - Sleep Timer View
struct SleepTimerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: PodViewModel
    @ObservedObject var sleepTimer = SleepTimerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "timer")
                Text(sleepTimer.stage == .running ? "TIMER RUNNING" : "SET TIMER")
                    .font(.custom(themeManager.currentTheme.fontName, size: 14))
                    .bold()
                Spacer()
            }
            .foregroundColor(themeManager.currentTheme.textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(themeManager.currentTheme.accentColor.opacity(0.1))
            
            Divider().background(themeManager.currentTheme.textColor)
            
            VStack(spacing: 0) {
                Spacer()
                
                if sleepTimer.stage == .running {
                let h = sleepTimer.remainingSeconds / 3600
                let m = (sleepTimer.remainingSeconds % 3600) / 60
                let s = sleepTimer.remainingSeconds % 60
                
                Text(String(format: "%02d:%02d:%02d", h, m, s))
                    .font(.custom(themeManager.currentTheme.fontName, size: 32))
                    .foregroundColor(themeManager.currentTheme.textColor)
                    .bold()
                
                Spacer()
                
                Text("Cancel")
                    .font(.custom(themeManager.currentTheme.fontName, size: 16))
                    .foregroundColor(themeManager.currentTheme.backgroundColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeManager.currentTheme.textColor)
            } else {
                HStack(spacing: 4) {
                    // Hours
                    VStack {
                        Text("HR")
                            .font(.custom(themeManager.currentTheme.fontName, size: 10))
                        Text(String(format: "%02d", sleepTimer.stage == .hours ? viewModel.scrollIndex : sleepTimer.selectedHours))
                            .font(.custom(themeManager.currentTheme.fontName, size: 24))
                            .padding(4)
                            .background(sleepTimer.stage == .hours ? themeManager.currentTheme.textColor : Color.clear)
                            .foregroundColor(sleepTimer.stage == .hours ? themeManager.currentTheme.backgroundColor : themeManager.currentTheme.textColor)
                    }
                    
                    Text(":")
                        .font(.custom(themeManager.currentTheme.fontName, size: 24))
                        .padding(.top, 14)
                    
                    // Minutes
                    VStack {
                        Text("MIN")
                            .font(.custom(themeManager.currentTheme.fontName, size: 10))
                        Text(String(format: "%02d", sleepTimer.stage == .minutes ? viewModel.scrollIndex : sleepTimer.selectedMinutes))
                            .font(.custom(themeManager.currentTheme.fontName, size: 24))
                            .padding(4)
                            .background(sleepTimer.stage == .minutes ? themeManager.currentTheme.textColor : Color.clear)
                            .foregroundColor(sleepTimer.stage == .minutes ? themeManager.currentTheme.backgroundColor : themeManager.currentTheme.textColor)
                    }
                    
                    Text(":")
                        .font(.custom(themeManager.currentTheme.fontName, size: 24))
                        .padding(.top, 14)
                    
                    // Seconds
                    VStack {
                        Text("SEC")
                            .font(.custom(themeManager.currentTheme.fontName, size: 10))
                        Text(String(format: "%02d", sleepTimer.stage == .seconds ? viewModel.scrollIndex : sleepTimer.selectedSeconds))
                            .font(.custom(themeManager.currentTheme.fontName, size: 24))
                            .padding(4)
                            .background(sleepTimer.stage == .seconds ? themeManager.currentTheme.textColor : Color.clear)
                            .foregroundColor(sleepTimer.stage == .seconds ? themeManager.currentTheme.backgroundColor : themeManager.currentTheme.textColor)
                    }
                }
                .foregroundColor(themeManager.currentTheme.textColor)
                
                Spacer()
                
                Text(sleepTimer.stage == .hours ? "Set Hours" : (sleepTimer.stage == .minutes ? "Set Minutes" : "Set Seconds"))
                    .font(.custom(themeManager.currentTheme.fontName, size: 12))
                    .foregroundColor(themeManager.currentTheme.textColor)
                Spacer()
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .applyThemeShadow(themeManager: themeManager)
            .background(ThemeBackgroundView())
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
                        Picker("Background Image", selection: $themeManager.customBackgroundId) {
                            ForEach(themeManager.availableBackgrounds) { bg in
                                Text(bg.name).tag(bg.id)
                            }
                        }
                        
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
        .applyThemeShadow(themeManager: themeManager)
        .background(ThemeBackgroundView())
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
        .applyThemeShadow(themeManager: themeManager)
        .background(ThemeBackgroundView())
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
