import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct GameViewModelTests {
    @Test func aChangedBookRequestBuildsOnlyTheLatestScene() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        await fixture.library.recordCompletion(of: "one")
        let firstBook = try #require(fixture.library.books.first { $0.id == "one" })
        let secondBook = try #require(fixture.library.books.first { $0.id == "two" })
        let model = GameViewModel(
            book: firstBook,
            wordLeapFeature: fixture.game,
            libraryFeature: fixture.library
        )

        let firstPreparation = model.prepare(firstBook)
        let secondPreparation = model.prepare(secondBook)
        await firstPreparation.value
        await secondPreparation.value

        #expect(model.activeLevel?.book.id == secondBook.id)
        #expect(model.scene != nil)
        model.leaveLevel()
    }

    @Test func lockedCastleShowsAnErrorWithoutCreatingAScene() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        let second = try #require(fixture.library.books.first { $0.id == "two" })
        let model = GameViewModel(
            book: second,
            wordLeapFeature: fixture.game,
            libraryFeature: fixture.library
        )
        await model.prepare(second).value
        #expect(model.scene == nil)
        #expect(model.preparationError?.contains("Castle 1") == true)
        model.leaveLevel()
    }

    @Test func deathPresentsStatsAndCheckpointRetryKeepsThem() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let feature = fixture.game
        let library = fixture.library
        await library.load().value
        let book = try #require(library.books.first)
        let model = GameViewModel(book: book, wordLeapFeature: feature, libraryFeature: library)
        await model.prepare(book, reduceMotion: true).value
        model.recordLanding(at: 0, word: "Pipa")
        model.showDeath(coins: 4, seconds: 125)
        #expect(model.isDeathPresented)
        #expect(model.gameOverStatistics.first { $0.title == "Time played" }?.value == "2:05")
        #expect(model.gameOverStatistics.first { $0.title == "Words collected" }?.value == "1")
        #expect(model.collectedDoubloons == 4)
        #expect(model.platformProgress.contains("platforms"))
        #expect(model.collectedDoubloonText == "4")
        #expect(model.collectedDoubloonAccessibilityLabel == "4 doubloons collected")
        model.retry()
        #expect(!model.isDeathPresented)
        #expect(feature.runStatistics.doubloonsCollected == 4)
        await model.prepare(book).value
        #expect(feature.runStatistics.wordsCollected == 0)
        #expect(feature.runStatistics.activeSeconds == 0)
        model.leaveLevel()
        #expect(model.scene == nil)
        #expect(feature.activeLevel == nil)
    }
}
