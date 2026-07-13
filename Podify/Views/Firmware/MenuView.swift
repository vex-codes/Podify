import SwiftUI

struct MenuView: View {
    @ObservedObject var viewModel: PodViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Text(viewModel.navigationPath.last ?? "iPod")
                    .font(.custom("Monaco", size: 14))
                    .bold()
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.1))
            
            Divider().background(Color.black)
            
            // The Scrollable List
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.currentMenu.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text(item.title)
                                    .font(.custom("Monaco", size: 16))
                                    .foregroundColor(viewModel.scrollIndex == index ? .white : .black)
                                    .lineLimit(1)
                                Spacer()
                                if case .folder = item.type {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(viewModel.scrollIndex == index ? .white : .black)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(viewModel.scrollIndex == index ? Color.black : Color.clear)
                            .id(index)
                        }
                    }
                }
                .onChange(of: viewModel.scrollIndex) { oldValue, newIndex in
                    withAnimation(.none) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
}
