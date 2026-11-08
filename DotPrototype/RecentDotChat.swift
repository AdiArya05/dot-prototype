import SwiftUI

struct RecentDotChat: Identifiable {
    let title: String
    let folder: String
    var id: String { title }

    // Sample recent cards for the portfolio demonstration.
    static let preview = [
        Self(title: "Portfolio 4", folder: "Portfolio"),
        Self(title: "Build personal Codex usage app", folder: "Random"),
        Self(title: "Catch Marketing", folder: "Catch")
    ]
}

struct RecentDotChats: View {
    let width: CGFloat
    let open: (RecentDotChat) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(RecentDotChat.preview) { chat in
                    Button {
                        open(chat)
                    } label: {
                        HStack(spacing: 11) {
                            Image("ChatGPTMark")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .foregroundStyle(.white)
                                .frame(width: 27, height: 27)
                                .frame(width: 38, height: 38)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .lineLimit(1)
                                Text(chat.folder)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 23)
                        .frame(width: width, height: 66)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(chat.title), \(chat.folder)")
                    .accessibilityIdentifier("recent-chat-\(chat.id)")
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .frame(width: width, height: 66)
        .clipShape(Capsule())
        .glassEffect(.regular.interactive())
    }
}
