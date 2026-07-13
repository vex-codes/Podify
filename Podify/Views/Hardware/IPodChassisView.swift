import SwiftUI

struct IPodChassisView: View {
    @StateObject private var viewModel = PodViewModel()
    
    var body: some View {
        ZStack {
            // Main chassis background
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                // Screen Area
                ScreenContainer(viewModel: viewModel)
                    .padding(.horizontal, 30)
                
                // Click Wheel
                ClickWheelView(
                    scrollIndex: $viewModel.scrollIndex,
                    onCenterTap: { viewModel.selectCurrentItem() },
                    onMenuTap: { viewModel.navigateBack() },
                    onPlayPauseTap: { AudioEngine.shared.togglePlayPause() },
                    onNextTap: { AudioEngine.shared.next() },
                    onPrevTap: { AudioEngine.shared.previous() }
                )
            }
            .padding(.vertical, 40)
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
