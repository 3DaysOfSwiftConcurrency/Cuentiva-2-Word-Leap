import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct LibraryViewModelTests {
    @Test func castlePresentationUsesSingularPlatformCopy() {
        let book = StoryBook(
            id: "one-word",
            storyteller: "Pipa",
            title: "One Word",
            englishTitle: "One Word",
            spanishPassages: ["Hola"]
        )
        let castle = AdventureCastle(book: book, number: 1, isCompleted: false, isUnlocked: true)

        #expect(AdventureCastlePresentation(castle: castle).statusText == "1 word platform")
    }

    @Test func firstReadyPresentationIncludesSavedLocksAndBalance() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.levelProgressStore.recordCompletion(of: "one")
        _ = await fixture.levelProgressStore.addDoubloons(12)
        let viewModel = LibraryViewModel(libraryFeature: fixture.libraryFeature)
        #expect(!viewModel.isReady)
        #expect(viewModel.books.isEmpty)
        await viewModel.load().value
        #expect(viewModel.isReady)
        #expect(viewModel.doubloonBalance == 12)
        #expect(viewModel.doubloonBalanceText == "12")
        #expect(viewModel.doubloonAccessibilityLabel == "12 doubloons")
        #expect(viewModel.castleCountText == "3 castles")
        #expect(viewModel.conqueredCountText == "1 conquered")
        #expect(viewModel.conqueredCount == 1)
        #expect(viewModel.castles.map(\.isUnlocked) == [true, true, false])
        #expect(viewModel.castles[0].statusText == "Conquered · Play again")
        #expect(viewModel.castles[1].statusText.contains("word platforms"))
        #expect(viewModel.castles[2].statusText == "Complete Castle 2")
        #expect(viewModel.errorMessage == nil)

        let revisit = viewModel.load()
        #expect(viewModel.isReady)
        #expect(viewModel.books.count == 3)
        #expect(viewModel.doubloonBalance == 12)
        await revisit.value
        #expect(viewModel.isReady)
    }

    @Test func failedPreparationCanRetryWithoutPublishingAnEmptyMenu() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let url = fixture.directory.appendingPathComponent("Library.dat")
        let validData = try Data(contentsOf: url)
        try Data("invalid library".utf8).write(to: url)
        let viewModel = LibraryViewModel(libraryFeature: fixture.libraryFeature)
        await viewModel.load().value
        #expect(!viewModel.isReady)
        #expect(viewModel.books.isEmpty)
        #expect(viewModel.errorMessage == "The Cuentiva book collection could not be opened.")
        #expect(!viewModel.isLoading)

        try validData.write(to: url)
        await viewModel.load().value
        #expect(viewModel.isReady)
        #expect(viewModel.books.count == 3)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func failedRemoteRefreshKeepsTheBundledLibraryPlayable() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let bookRepository = CuentivaBookRepository(
            networkingManager: NetworkingManager { _ in throw URLError(.notConnectedToInternet) },
            bundledLibraryURL: fixture.directory.appendingPathComponent("Library.dat")
        )
        let libraryFeature = LibraryFeature(
            bookRepository: bookRepository,
            levelProgressStore: fixture.levelProgressStore
        )
        let viewModel = LibraryViewModel(libraryFeature: libraryFeature)

        await viewModel.load().value
        let bundledBookIDs = viewModel.books.map(\.id)
        await viewModel.refresh().value

        #expect(viewModel.books.map(\.id) == bundledBookIDs)
        #expect(viewModel.isReady)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage ==
            "GitHub could not refresh the collection. Your bundled books are still ready to play.")
    }

    @Test func balanceLoadsSavedTreasureAndReflectsNewGameplayCredits() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        _ = await fixture.levelProgressStore.addDoubloons(1)
        let viewModel = LibraryViewModel(libraryFeature: fixture.libraryFeature)
        await viewModel.load().value
        #expect(viewModel.doubloonBalance == 1)
        #expect(viewModel.doubloonAccessibilityLabel == "1 doubloon")
        let first = try #require(viewModel.books.first)
        await fixture.wordLeapFeature.startAdventure(with: first).value
        await fixture.wordLeapFeature.recordCollectedDoubloons(2)?.value
        #expect(viewModel.doubloonBalance == 3)
        #expect(viewModel.doubloonAccessibilityLabel == "3 doubloons")
    }

    @Test func mapSelectionHonoursLocksAndReflectsCompletion() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let viewModel = LibraryViewModel(libraryFeature: fixture.libraryFeature)
        #expect(viewModel.castles.isEmpty)
        #expect(viewModel.selectedBook == nil)
        await viewModel.load().value
        let first = try #require(viewModel.books.first)
        let second = try #require(viewModel.books.first { $0.id == "two" })
        viewModel.select(second)
        #expect(viewModel.selectedBook == nil)
        viewModel.select(first)
        #expect(viewModel.selectedBook?.id == "one")
        viewModel.selectedBook = nil
        await fixture.libraryFeature.recordCompletion(of: first.id).value
        #expect(viewModel.conqueredCount == 1)
        #expect(viewModel.castles.map(\.number) == [1, 2, 3])
        viewModel.select(second)
        #expect(viewModel.selectedBook?.id == "two")
    }

    @Test func mapDoesNotCountCompletionsForRemovedBooks() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.levelProgressStore.recordCompletion(of: "removed")
        let viewModel = LibraryViewModel(libraryFeature: fixture.libraryFeature)
        await viewModel.load().value
        #expect(viewModel.conqueredCount == 0)
        #expect(viewModel.castles.map(\.isUnlocked) == [true, false, false])
    }
}
