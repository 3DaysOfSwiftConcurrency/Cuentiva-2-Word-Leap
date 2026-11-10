import SwiftUI

/// An illuminated reading surface inside the same world as the adventure.
struct CompletedBookPagesView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var viewModel: CompletedBookPagesViewModel

    init(book: StoryBook) {
        _viewModel = State(initialValue: CompletedBookPagesViewModel(book: book))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                CompletedBookCover(book: viewModel.book).frame(maxWidth: .infinity)
                Text(viewModel.englishTitle)
                    .font(.system(.title2, design: .serif))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(18).worldPanel()
                ForEach(viewModel.pages) { page in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(page.spanish)
                            .font(.system(.title3, design: .serif)).lineSpacing(5)
                        if let english = page.english {
                            Text(english)
                                .foregroundStyle(themeManager.worldSecondaryText).lineSpacing(4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22).worldPanel()
                }
            }
            .frame(maxWidth: 660)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(themeManager.worldText)
        .background { WorldBackdrop(shade: 0.32) }
    }
}
