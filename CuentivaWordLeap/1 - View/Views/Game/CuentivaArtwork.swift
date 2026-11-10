// Adapted from Cuentiva's BookCover and DoubloonIcon.
import SwiftUI

enum CuentivaArtwork {
    static let coinHighlight = Color(red: 1, green: 0.92, blue: 0.60)
    static let coinGold = Color(red: 0.95, green: 0.66, blue: 0.17)
    static let coinShadow = Color(red: 0.40, green: 0.23, blue: 0.035)
    static let coverColours: [Color] = [
        Color(red: 0.72, green: 0.35, blue: 0.23), Color(red: 0.25, green: 0.39, blue: 0.43),
        Color(red: 0.43, green: 0.45, blue: 0.27), Color(red: 0.51, green: 0.35, blue: 0.40),
        Color(red: 0.67, green: 0.46, blue: 0.24)
    ]
}
struct DoubloonArtwork: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [CuentivaArtwork.coinHighlight, CuentivaArtwork.coinGold,
                CuentivaArtwork.coinShadow], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(CuentivaArtwork.coinShadow, lineWidth: size * 0.035)
            Circle().inset(by: size * 0.09)
                .strokeBorder(CuentivaArtwork.coinHighlight.opacity(0.9), lineWidth: size * 0.025)
            Circle().inset(by: size * 0.14)
                .strokeBorder(CuentivaArtwork.coinShadow.opacity(0.5), lineWidth: size * 0.018)
            Image(systemName: "book.closed.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(CuentivaArtwork.coinShadow)
                .shadow(color: CuentivaArtwork.coinHighlight, radius: 0, x: 0, y: size * 0.015)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CompletedBookCover: View {
    let book: StoryBook

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(book.backgroundAssetName)
                .resizable().scaledToFill().frame(width: 190, height: 260)
                .overlay(.black.opacity(0.4))
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.5)],
                                   startPoint: .top, endPoint: .bottom)
                }
            Rectangle().fill(.black.opacity(0.1)).frame(width: 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 10) {
                Text("CUENTIVA / \(book.cover.level)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                Text(book.title)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .lineLimit(4).minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                Image(systemName: book.cover.symbol == "train.side" ? "tram.fill" : book.cover.symbol)
                    .font(.system(size: 44, weight: .ultraLight))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 6)
                Text(book.storyteller.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1)
                    .padding(.trailing, 44)
            }
            .padding(18)
            .foregroundStyle(.white)
            Image(book.portraitAssetName).resizable().scaledToFill()
                .frame(width: 48, height: 48).clipShape(Circle()).padding(12)
        }
        .frame(width: 190, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CuentivaArtwork.coinHighlight.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.title), by \(book.storyteller)")
    }
}

struct BookCompletionReveal: View {
    @Environment(ThemeManager.self) private var themeManager
    let book: StoryBook
    let title: String
    let coins: Int
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
                    CompletedBookCover(book: book)
                    HStack(spacing: 8) {
                        DoubloonArtwork(size: 30)
                        Text("\(coins) doubloons collected").font(.headline)
                    }
                    HStack(spacing: 12) {
                        Button(action: read) {
                            Label("Read the book", systemImage: "book.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                        }
                        .worldPanel(cornerRadius: 28)
                        Button(action: hasNextLevel ? next : leave) {
                            Label(hasNextLevel ? "Next level" : "Adventure", systemImage: "arrow.right")
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
