import Observation

@MainActor @Observable
final class CompletedBookPagesViewModel {
    let cover: CompletedBookCoverPresentation
    let pages: [CompletedBookPage]
    let englishTitle: String

    init(book: StoryBook) {
        cover = CompletedBookCoverPresentation(book: book)
        englishTitle = book.englishTitle
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

}

struct CompletedBookPage: Identifiable, Equatable {
    let index: Int
    let spanish: String
    let english: String?

    var id: Int { index }
}
