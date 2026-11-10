import Testing
@testable import CuentivaWordLeap

@MainActor
struct CompletedBookPagesViewModelTests {
    @Test func pairsAvailableTranslationsWithoutInventingMissingCopy() {
        let book = StoryBook(
            id: "test",
            storyteller: "Pipa",
            title: "Un cuento",
            englishTitle: "A Story",
            spanishPassages: ["Primera.", "Segunda.", "Tercera."],
            englishPassages: ["First.", "", "Third."]
        )

        let viewModel = CompletedBookPagesViewModel(book: book)

        #expect(viewModel.englishTitle == "A Story")
        #expect(viewModel.pages.map(\.spanish) == ["Primera.", "Segunda.", "Tercera."])
        #expect(viewModel.pages.map(\.english) == ["First.", nil, "Third."])
    }
}
