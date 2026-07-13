import SwiftUI

struct ScreenContainer: View {
    @ObservedObject var viewModel: PodViewModel
    
    var body: some View {
        Rectangle()
            .fill(Color(red: 196/255, green: 212/255, blue: 205/255)) // #C4D4CD
            .aspectRatio(4/3, contentMode: .fit)
            .overlay(
                Group {
                    if viewModel.isNowPlayingPresented {
                        NowPlayingView()
                    } else {
                        MenuView(viewModel: viewModel)
                    }
                }
                .padding(4) // Bezel padding
            )
            .border(Color.black, width: 2) // Inner bezel
    }
}
