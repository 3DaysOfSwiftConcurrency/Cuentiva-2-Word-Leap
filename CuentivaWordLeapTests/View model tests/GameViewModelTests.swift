import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct GameViewModelTests {
    @Test func lockedCastleShowsAnErrorWithoutCreatingAScene() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        let model = GameViewModel(wordLeapFeature: fixture.game, libraryFeature: fixture.library)
        let second = try #require(fixture.library.books.first { $0.id == "two" })
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
        let model = GameViewModel(wordLeapFeature: feature, libraryFeature: library)
        let book = try #require(library.books.first)
        await model.prepare(book, reduceMotion: true).value
        model.recordLanding(at: 0, word: "Pipa")
        model.showDeath(coins: 4, seconds: 125)
        #expect(model.isDeathPresented)
        #expect(model.gameOverStatistics.first { $0.title == "Time played" }?.value == "2:05")
        #expect(model.gameOverStatistics.first { $0.title == "Words collected" }?.value == "1")
        #expect(model.collectedDoubloons == 4)
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
