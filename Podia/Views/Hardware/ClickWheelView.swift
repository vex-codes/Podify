import SwiftUI
import AudioToolbox

struct ClickWheelView: View {
    @Binding var scrollIndex: Int
    var onScroll: ((Int) -> Void)? = nil
    var onCenterTap: () -> Void
    var onMenuTap: () -> Void
    var onPlayPauseTap: () -> Void
    var onNextTap: () -> Void
    var onPrevTap: () -> Void
    
    @State private var lastAngle: Double = 0
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(themeManager.currentTheme.wheelColor) // The wheel
                .overlay(
                    VStack {
                        Text("MENU").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            .padding(.top, 15)
                            .onTapGesture { onMenuTap(); UIImpactFeedbackGenerator(style: .medium).impactOccurred(); AudioServicesPlaySystemSound(1104) }
                        Spacer()
                        Text("▶︎||").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            .padding(.bottom, 15)
                            .onTapGesture { onPlayPauseTap(); UIImpactFeedbackGenerator(style: .medium).impactOccurred(); AudioServicesPlaySystemSound(1104) }
                    }
                )
                .overlay(
                    HStack {
                        Text("|◀︎").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            .padding(.leading, 15)
                            .onTapGesture { onPrevTap(); UIImpactFeedbackGenerator(style: .medium).impactOccurred(); AudioServicesPlaySystemSound(1104) }
                        Spacer()
                        Text("▶︎|").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            .padding(.trailing, 15)
                            .onTapGesture { onNextTap(); UIImpactFeedbackGenerator(style: .medium).impactOccurred(); AudioServicesPlaySystemSound(1104) }
                    }
                )
                .overlay(
                    Circle()
                        .fill(themeManager.currentTheme.centerButtonColor)
                        .frame(width: 80, height: 80) // The center button
                        .onTapGesture {
                            onCenterTap()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            AudioServicesPlaySystemSound(1104)
                        }
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                            let currentAngle = atan2(vector.dy, vector.dx)
                            let angleDifference = currentAngle - lastAngle
                            if abs(angleDifference) > 0.15 {
                                let delta = angleDifference > 0 ? 1 : -1
                                if let onScroll = onScroll {
                                    onScroll(delta)
                                } else {
                                    scrollIndex += delta
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                AudioServicesPlaySystemSound(1104)
                                lastAngle = currentAngle
                            }
                        }
                )
        }
        .frame(width: 250, height: 250)
    }
}

#Preview {
    ClickWheelView(scrollIndex: .constant(0), onCenterTap: {}, onMenuTap: {}, onPlayPauseTap: {}, onNextTap: {}, onPrevTap: {})
}
