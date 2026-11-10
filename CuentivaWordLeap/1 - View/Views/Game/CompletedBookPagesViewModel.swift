import Observation

@MainActor @Observable
final class CompletedBookPagesViewModel {
    let cover: CompletedBookCoverPresentation
    let pages: [CompletedBookPage]
    let englishTitle: String

    init(book: StoryBook) {
        cover = CompletedBookCoverPresentation(book: book)
        englishTitle = book.englishTitle
        pages = book.bilingualPassages.enumerated().map { index, passage in
            return CompletedBookPage(
                index: index,
                spanish: passage.spanish,
                english: passage.english
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
