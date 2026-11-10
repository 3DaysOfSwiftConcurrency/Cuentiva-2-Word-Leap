import Testing
@testable import CuentivaWordLeap

struct StoryBookTests {
    @Test func pairsTranslationsWithoutInventingMissingContent() {
        let book = StoryBook(
            id: "test",
            storyteller: "Pipa",
            title: "Un cuento",
            englishTitle: "A Story",
            spanishPassages: ["Primera.", "Segunda.", "Tercera."],
            englishPassages: ["First.", "", "Third."]
        )

        #expect(book.bilingualPassages == [
            StoryBookPassage(spanish: "Primera.", english: "First."),
            StoryBookPassage(spanish: "Segunda.", english: nil),
            StoryBookPassage(spanish: "Tercera.", english: "Third.")
        ])
    }
}
