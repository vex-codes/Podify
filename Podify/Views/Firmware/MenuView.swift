import SwiftUI

struct MenuView: View {
    @ObservedObject var viewModel: PodViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Text(viewModel.navigationPath.last ?? "Podify")
                    .font(.custom(themeManager.currentTheme.fontName, size: 14))
                    .bold()
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.accentColor.opacity(0.1))
            .foregroundColor(themeManager.currentTheme.textColor)
            
            Divider().background(themeManager.currentTheme.textColor)
            
            // The Scrollable List
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.currentMenu.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text(item.title)
                                    .font(.custom(themeManager.currentTheme.fontName, size: 16))
                                    .foregroundColor(viewModel.scrollIndex == index ? themeManager.currentTheme.backgroundColor : themeManager.currentTheme.textColor)
                                    .lineLimit(1)
                                Spacer()
                                Group {
                                    switch item.type {
                                    case .folder:
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .bold))
                                    case .playlist:
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 10, weight: .bold))
                                    case .track:
                                        Image(systemName: "music.note")
                                            .font(.system(size: 10, weight: .bold))
                                    case .shuffleToggle:
                                        Image(systemName: "shuffle")
                                            .font(.system(size: 10, weight: .bold))
                                    case .brokenFolder:
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 10, weight: .bold))
                                    case .back:
                                        EmptyView()
                                    }
                                }
                                .foregroundColor(viewModel.scrollIndex == index ? themeManager.currentTheme.backgroundColor : themeManager.currentTheme.textColor)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(viewModel.scrollIndex == index ? themeManager.currentTheme.accentColor : Color.clear)
                            .id(index)
                        }
                    }
                }
                .onChange(of: viewModel.scrollIndex) { oldValue, newIndex in
                    withAnimation(.none) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .applyThemeShadow(themeManager: themeManager)
                .background(ThemeBackgroundView())
            }
        }
        .background(themeManager.currentTheme.backgroundColor)
    }
}
