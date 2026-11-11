import Testing
@testable import CuentivaWordLeap

@MainActor
struct WordLeapFeatureTests {
    @Test func aChangedBookRequestReplacesPreparationInsteadOfBeingDropped() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        await fixture.libraryFeature.recordCompletion(of: "one")
        let firstBook = try #require(fixture.libraryFeature.books.first { $0.id == "one" })
        let secondBook = try #require(fixture.libraryFeature.books.first { $0.id == "two" })

        let firstPreparation = fixture.wordLeapFeature.start(book: firstBook)
        let secondPreparation = fixture.wordLeapFeature.start(book: secondBook)
        await firstPreparation.value
        await secondPreparation.value

        #expect(fixture.wordLeapFeature.activeLevel?.book.id == secondBook.id)
        #expect(fixture.wordLeapFeature.preparationFailure == nil)
    }

    @Test func completingTheFinalWordCompletesTheLevel() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        let book = try #require(fixture.libraryFeature.books.first)
        await fixture.wordLeapFeature.start(book: book).value
        let plan = try #require(fixture.wordLeapFeature.activeLevel)
        fixture.wordLeapFeature.recordLanding(at: plan.words.count - 1)
        #expect(fixture.wordLeapFeature.landedWordCount == plan.words.count)
        #expect(fixture.wordLeapFeature.isLevelComplete)
        // Wait for the earned completion to persist before removing test storage.
        await fixture.wordLeapFeature.start(book: book).value
        #expect(await fixture.levelProgressStore.completedBookIDs() == [book.id])
    }
}
