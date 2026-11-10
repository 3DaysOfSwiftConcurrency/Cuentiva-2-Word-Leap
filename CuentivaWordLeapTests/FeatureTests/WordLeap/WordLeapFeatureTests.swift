import Testing
@testable import CuentivaWordLeap

@MainActor
struct WordLeapFeatureTests {
    @Test func completingTheFinalWordCompletesTheLevel() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        let book = try #require(fixture.library.books.first)
        await fixture.game.start(book: book).value
        let plan = try #require(fixture.game.activeLevel)
        fixture.game.recordLanding(at: plan.words.count - 1)
        #expect(fixture.game.landedWordCount == plan.words.count)
        #expect(fixture.game.isLevelComplete)
        // Wait for the earned completion to persist before removing test storage.
        await fixture.game.start(book: book).value
        #expect(await fixture.progress.completedBookIDs() == [book.id])
    }
}
