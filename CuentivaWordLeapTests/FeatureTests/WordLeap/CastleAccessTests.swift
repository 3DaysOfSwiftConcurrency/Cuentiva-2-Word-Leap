import Testing
@testable import CuentivaWordLeap

@MainActor
struct CastleAccessTests {
    @Test func lockedAndUnknownLevelsCannotStartOrChangeRunTotals() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        let second = try #require(fixture.library.books.first { $0.id == "two" })
        await fixture.game.start(book: second).value
        #expect(fixture.game.activeLevel == nil)
        #expect(fixture.game.preparationFailure as? CastleAccessError == .locked(previousCastle: 1))
        #expect(fixture.game.runStatistics.wordsCollected == 0)
        let unknown = StoryBook(id: "unknown", storyteller: "Pipa", title: "", englishTitle: "", spanishPassages: ["X"])
        await fixture.game.start(book: unknown).value
        #expect(fixture.game.activeLevel == nil)
        #expect(fixture.game.preparationFailure as? CastleAccessError == .unknownBook)
        #expect(await fixture.progress.completedBookIDs().isEmpty)
    }

    @Test func partialPlayStaysLockedButImmediateNextLevelWaitsForCompletion() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        let first = try #require(fixture.library.books.first)
        let second = try #require(fixture.library.books.first { $0.id == "two" })
        await fixture.game.start(book: first).value
        fixture.game.recordLanding(at: 0)
        fixture.game.recordRunProgress(doubloons: 2, activeSeconds: 12)
        await fixture.game.start(book: second, continuingRun: true).value
        #expect(fixture.game.activeLevel?.book.id == "one")
        #expect(fixture.game.preparationFailure as? CastleAccessError == .locked(previousCastle: 1))
        #expect(fixture.game.runStatistics.doubloonsCollected == 2)
        #expect(!fixture.library.canPlay(second))
        let plan = try #require(fixture.game.activeLevel)
        for index in plan.words.indices { fixture.game.recordLanding(at: index) }
        await fixture.game.start(book: second, continuingRun: true).value
        #expect(fixture.game.preparationFailure == nil)
        #expect(fixture.game.activeLevel?.book.id == "two")
        #expect(fixture.game.runStatistics.doubloonsCollected == 2)
        #expect(fixture.library.canPlay(second))
        #expect(await fixture.progress.completedBookIDs() == ["one"])
    }

    @Test func leavingDoesNotCancelEarnedUnlockAndSuppliedBookCannotBypassCatalogue() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let forged = StoryBook(id: "one", storyteller: "Pipa", title: "", englishTitle: "", spanishPassages: ["X"])
        await fixture.game.start(book: forged).value
        let plan = try #require(fixture.game.activeLevel)
        #expect(plan.book.title == "Uno")
        #expect(plan.words.count > 1)
        for index in plan.words.indices { fixture.game.recordLanding(at: index) }
        fixture.game.endLevel()
        let second = try #require(fixture.library.books.first { $0.id == "two" })
        await fixture.game.start(book: second).value
        #expect(fixture.game.activeLevel?.book.id == "two")
        #expect(await fixture.progress.completedBookIDs() == ["one"])
    }

    @Test func cancelledPreparationDoesNotStartOrUnlockACastle() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        let first = try #require(fixture.library.books.first)
        let task = fixture.game.start(book: first)
        fixture.game.endLevel()
        await task.value
        #expect(fixture.game.activeLevel == nil)
        #expect(fixture.library.completedBookIDs.isEmpty)
        await fixture.game.start(book: first).value
        #expect(fixture.game.activeLevel?.book.id == first.id)
    }
}
