import SwiftUI

struct HomeScreen: View, Equatable {
    let size: CGSize
    let openAsk: () -> Void

    private let homeApps: [StockApp] = [.calendar, .photos, .settings]
    private let dockApps: [StockApp] = [.messages, .safari]
    private var iconSize: CGFloat { min(64, (size.width - 60) / 4) }
    private var gridWidth: CGFloat { min(size.width - 34, 400) }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.size == rhs.size }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(homeApps) { app in
                    VStack(spacing: 5) {
                        icon(for: app)
                        Text(app.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
                    }
                    .frame(maxWidth: .infinity)
                }
                Color.clear.frame(width: gridWidth / 4, height: 1)
            }
            .frame(width: gridWidth)
            .padding(.top, min(244, size.height * 0.28))
            .accessibilityHidden(true)

            Spacer(minLength: 0)

            Button(action: openAsk) {
                Label("Search", systemImage: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 11)
                    .frame(height: 29)
                    .glassEffect(.regular.interactive())
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-search")
            .padding(.bottom, 11)

            HStack(spacing: 28) {
                ForEach(dockApps) { app in
                    icon(for: app)
                }
            }
            .frame(width: gridWidth, height: iconSize + 37)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .padding(.bottom, 20)
            .accessibilityHidden(true)
        }
        .frame(width: size.width, height: size.height)

    }

    private func icon(for app: StockApp) -> some View {
        Image("Stock\(app.rawValue)")
            .resizable()
            .interpolation(.high)
            .frame(width: iconSize, height: iconSize)
            .clipShape(.rect(cornerRadius: iconSize * 0.227))
    }
}

private enum StockApp: String, Identifiable {
    case calendar = "Calendar", photos = "Photos", settings = "Settings"
    case messages = "Messages", safari = "Safari"

    var name: String { rawValue }
    var id: String { rawValue }
}

struct Wallpaper: View {
    var body: some View {
        GeometryReader { geometry in
            Image("StockWallpaper")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .accessibilityHidden(true)
        }
    }
}
