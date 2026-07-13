import SwiftUI

struct ScreenContainer: View {
    @ObservedObject var viewModel: PodViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Rectangle()
            .fill(themeManager.currentTheme.backgroundColor)
            .aspectRatio(4/3, contentMode: .fit)
            .overlay(
                VStack(spacing: 0) {
                    StatusBarView()
                    
                    Group {
                        if viewModel.isNowPlayingPresented {
                            NowPlayingView()
                        } else if viewModel.isCoverFlowPresented {
                            CoverFlowView(tracks: viewModel.playbackQueue, scrollIndex: viewModel.scrollIndex)
                        } else if viewModel.isSettingsPresented {
                            SettingsView(viewModel: viewModel)
                        } else {
                            MenuView(viewModel: viewModel)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(4) // Bezel padding
            )
            .border(themeManager.currentTheme.bezelColor, width: 2) // Inner bezel
    }
}
