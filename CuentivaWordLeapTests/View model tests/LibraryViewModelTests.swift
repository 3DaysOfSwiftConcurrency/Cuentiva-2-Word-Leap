import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct LibraryViewModelTests {
    @Test func firstReadyPresentationIncludesSavedLocksAndBalance() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.progress.recordCompletion(of: "one")
        _ = await fixture.progress.addDoubloons(12)
        let viewModel = LibraryViewModel(libraryFeature: fixture.library)
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
        let viewModel = LibraryViewModel(libraryFeature: fixture.library)
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
        let repository = CuentivaBookRepository(
            networkingManager: NetworkingManager { _ in throw URLError(.notConnectedToInternet) },
            bundledLibraryURL: fixture.directory.appendingPathComponent("Library.dat")
        )
        let library = LibraryFeature(bookRepository: repository, levelProgressStore: fixture.progress)
        let viewModel = LibraryViewModel(libraryFeature: library)

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
        _ = await fixture.progress.addDoubloons(12)
        let viewModel = LibraryViewModel(libraryFeature: fixture.library)
        await viewModel.load().value
        #expect(viewModel.doubloonBalance == 12)
        let first = try #require(viewModel.books.first)
        await fixture.game.start(book: first).value
        await fixture.game.recordCollectedDoubloons(2)?.value
        #expect(viewModel.doubloonBalance == 14)
    }

    @Test func mapSelectionHonoursLocksAndReflectsCompletion() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let viewModel = LibraryViewModel(libraryFeature: fixture.library)
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
        await fixture.library.recordCompletion(of: first.id)
        #expect(viewModel.conqueredCount == 1)
        #expect(viewModel.castles.map(\.number) == [1, 2, 3])
        viewModel.select(second)
        #expect(viewModel.selectedBook?.id == "two")
    }

    @Test func mapDoesNotCountCompletionsForRemovedBooks() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.progress.recordCompletion(of: "removed")
        let viewModel = LibraryViewModel(libraryFeature: fixture.library)
        await viewModel.load().value
        #expect(viewModel.conqueredCount == 0)
        #expect(viewModel.castles.map(\.isUnlocked) == [true, false, false])
    }
}
