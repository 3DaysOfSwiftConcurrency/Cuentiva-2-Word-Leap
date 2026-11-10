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
        let viewModel = GameViewModel(
            book: firstBook,
            wordLeapFeature: fixture.game,
            libraryFeature: fixture.library
        )

        let firstPreparation = viewModel.prepare(firstBook)
        let secondPreparation = viewModel.prepare(secondBook)
        await firstPreparation.value
        await secondPreparation.value

        #expect(viewModel.activeLevel?.book.id == secondBook.id)
        #expect(viewModel.scene != nil)
        viewModel.leaveLevel()
    }

    @Test func lockedCastleShowsAnErrorWithoutCreatingAScene() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        let second = try #require(fixture.library.books.first { $0.id == "two" })
        let viewModel = GameViewModel(
            book: second,
            wordLeapFeature: fixture.game,
            libraryFeature: fixture.library
        )
        await viewModel.prepare(second).value
        #expect(viewModel.scene == nil)
        #expect(viewModel.preparationError == "Complete Castle 1 to unlock this adventure.")
        viewModel.leaveLevel()
    }

    @Test func removedBookShowsPresentationCopyWithoutCreatingAScene() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        let removedBook = StoryBook(
            id: "removed",
            storyteller: "Pipa",
            title: "Removed",
            englishTitle: "Removed",
            spanishPassages: ["Pipa salta."]
        )
        let viewModel = GameViewModel(
            book: removedBook,
            wordLeapFeature: fixture.game,
            libraryFeature: fixture.library
        )

        await viewModel.prepare(removedBook).value

        #expect(viewModel.scene == nil)
        #expect(viewModel.preparationError == "This book is no longer on the adventure map.")
        viewModel.leaveLevel()
    }

    @Test func deathPresentsStatsAndCheckpointRetryKeepsThem() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let feature = fixture.game
        let library = fixture.library
        await library.load().value
        let book = try #require(library.books.first)
        let viewModel = GameViewModel(book: book, wordLeapFeature: feature, libraryFeature: library)
        await viewModel.prepare(book, reduceMotion: true).value
        viewModel.recordLanding(at: 0, word: "Pipa")
        viewModel.showDeath(collectedDoubloons: 4, activeSeconds: 125)
        #expect(viewModel.isDeathPresented)
        #expect(viewModel.gameOverStatistics.first { $0.title == "Time played" }?.displayValue == "2:05")
        #expect(viewModel.gameOverStatistics.first { $0.title == "Words collected" }?.displayValue == "1")
        #expect(viewModel.collectedDoubloons == 4)
        #expect(viewModel.platformProgress.contains("platforms"))
        #expect(viewModel.collectedDoubloonText == "4")
        #expect(viewModel.collectedDoubloonAccessibilityLabel == "4 doubloons collected")
        #expect(viewModel.completionDoubloonText == "4 doubloons collected")
        #expect(viewModel.completedBookCover.title == book.title)
        viewModel.retry()
        #expect(!viewModel.isDeathPresented)
        #expect(feature.runStatistics.doubloonsCollected == 4)
        await viewModel.prepare(book).value
        #expect(feature.runStatistics.wordsCollected == 0)
        #expect(feature.runStatistics.activeSeconds == 0)
        viewModel.leaveLevel()
        #expect(viewModel.scene == nil)
        #expect(feature.activeLevel == nil)
    }

    @Test func nextLevelReturnsItsPreparationAndContinuesTheAdventure() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        let firstBook = try #require(fixture.library.books.first)
        let viewModel = GameViewModel(
            book: firstBook,
            wordLeapFeature: fixture.game,
            libraryFeature: fixture.library
        )
        await viewModel.prepare().value
        let firstPlan = try #require(viewModel.activeLevel)
        for wordIndex in firstPlan.words.indices {
            viewModel.recordLanding(at: wordIndex, word: firstPlan.words[wordIndex])
        }

        let nextLevelPreparation = try #require(viewModel.startNextLevel())
        await nextLevelPreparation.value

        #expect(viewModel.currentBook.id == "two")
        #expect(viewModel.scene != nil)
        #expect(fixture.game.runStatistics.levelsCompleted == 1)
        viewModel.leaveLevel()
    }
}
