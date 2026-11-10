import Observation

@MainActor @Observable
final class CompletedBookPagesViewModel {
    let book: StoryBook
    let pages: [CompletedBookPage]

    init(book: StoryBook) {
        self.book = book
        pages = book.spanishPassages.enumerated().map { index, spanish in
            let translation = book.englishPassages.indices.contains(index)
                ? book.englishPassages[index] : ""
            return CompletedBookPage(
                index: index,
                spanish: spanish,
                english: translation.isEmpty ? nil : translation
            )
        }
    }

    var englishTitle: String { book.englishTitle }
}

struct CompletedBookPage: Identifiable, Equatable {
    let index: Int
    let spanish: String
    let english: String?

    var id: Int { index }
}
