import SwiftUI

struct CompletedBookCoverPresentation: Equatable {
    let backgroundAssetName: String
    let levelText: String
    let title: String
    let symbol: String
    let storyteller: String
    let portraitAssetName: String
    let accessibilityLabel: String

    init(book: StoryBook) {
        backgroundAssetName = book.backgroundAssetName
        levelText = "CUENTIVA / \(book.cover.level)"
        title = book.title
        symbol = book.cover.symbol == "train.side" ? "tram.fill" : book.cover.symbol
        storyteller = book.storyteller.uppercased()
        portraitAssetName = book.portraitAssetName
        accessibilityLabel = "\(book.title), by \(book.storyteller)"
    }
}

struct CompletedBookCover: View {
    let presentation: CompletedBookCoverPresentation

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(presentation.backgroundAssetName)
                .resizable().scaledToFill().frame(width: 190, height: 260)
                .overlay(.black.opacity(0.4))
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.5)],
                                   startPoint: .top, endPoint: .bottom)
                }
            Rectangle().fill(.black.opacity(0.1)).frame(width: 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 10) {
                Text(presentation.levelText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                Text(presentation.title)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .lineLimit(4).minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                Image(systemName: presentation.symbol)
                    .font(.system(size: 44, weight: .ultraLight))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 6)
                Text(presentation.storyteller)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1)
                    .padding(.trailing, 44)
            }
            .padding(18)
            .foregroundStyle(.white)
            Image(presentation.portraitAssetName).resizable().scaledToFill()
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
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
