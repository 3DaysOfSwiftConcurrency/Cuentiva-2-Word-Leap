import SwiftUI

struct BookCompletionReveal: View {
    @Environment(ThemeManager.self) private var themeManager
    let cover: CompletedBookCoverPresentation
    let title: String
    let doubloonText: String
    let primaryActionTitle: String
    let hasNextLevel: Bool
    let read: () -> Void
    let next: () -> Void
    let leave: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    Text(title)
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    CompletedBookCover(presentation: cover)
                    HStack(spacing: 8) {
                        DoubloonArtwork(size: 30)
                        Text(doubloonText).font(.headline)
                    }
                    HStack(spacing: 12) {
                        Button(action: read) {
                            Label("Read the book", systemImage: "book.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                        }
                        .worldPanel(cornerRadius: 28)
                        Button(action: hasNextLevel ? next : leave) {
                            Label(primaryActionTitle, systemImage: "arrow.right")
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                        }
                        .foregroundStyle(themeManager.worldShadow)
                        .background(themeManager.worldAccent, in: Capsule())
                    }
                    .font(.subheadline.weight(.bold)).buttonStyle(.plain)
                }
                .foregroundStyle(themeManager.worldText)
                .padding(24)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
    }
}
