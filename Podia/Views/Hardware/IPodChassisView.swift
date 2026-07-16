import SwiftUI

struct IPodChassisView: View {
    @StateObject private var viewModel = PodViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Main chassis background
            themeManager.currentTheme.chassisColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // Screen Area
                ScreenContainer(viewModel: viewModel)
                    .padding(.horizontal, 30)
                
                // Click Wheel
                ClickWheelView(
                    scrollIndex: $viewModel.scrollIndex,
                    onScroll: { delta in
                        viewModel.handleScroll(delta: delta)
                    },
                    onCenterTap: {
                        if viewModel.isSettingsPresented {
                            if viewModel.settingsState == .main {
                                viewModel.selectCurrentItem()
                            } else if viewModel.settingsState == .themes {
                                let themes = ThemeFactory.presets.map { $0.id } + ["custom"]
                                if viewModel.scrollIndex >= 0 && viewModel.scrollIndex < themes.count {
                                    themeManager.applyTheme(id: themes[viewModel.scrollIndex])
                                }
                            } else if viewModel.settingsState == .sleepTimer {
                                SleepTimerManager.shared.advanceStage(scrollIndex: viewModel.scrollIndex)
                                viewModel.scrollIndex = 0
                            }
                        } else {
                            viewModel.selectCurrentItem()
                        }
                    },
                    onMenuTap: { viewModel.navigateBack() },
                    onPlayPauseTap: { AudioEngine.shared.togglePlayPause() },
                    onNextTap: { AudioEngine.shared.next() },
                    onPrevTap: { AudioEngine.shared.previous() }
                )
                .aspectRatio(1.0, contentMode: .fit)
                .padding(.horizontal, 40)
            }
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $viewModel.isShowingDocumentPicker) {
            DocumentPicker { url in
                viewModel.syncFolder(url: url)
            }
        }
    }
}

#Preview {
    IPodChassisView()
}
