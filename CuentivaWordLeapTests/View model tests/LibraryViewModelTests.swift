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
        let model = LibraryViewModel(libraryFeature: fixture.library)
        #expect(!model.isReady)
        #expect(model.books.isEmpty)
        await model.load().value
        #expect(model.isReady)
        #expect(model.doubloonBalance == 12)
        #expect(model.conqueredCount == 1)
        #expect(model.castles.map(\.isUnlocked) == [true, true, false])
        #expect(model.errorMessage == nil)

        let revisit = model.load()
        #expect(model.isReady)
        #expect(model.books.count == 3)
        #expect(model.doubloonBalance == 12)
        await revisit.value
        #expect(model.isReady)
    }

    @Test func failedPreparationCanRetryWithoutPublishingAnEmptyMenu() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let url = fixture.directory.appendingPathComponent("Library.dat")
        let validData = try Data(contentsOf: url)
        try Data("invalid library".utf8).write(to: url)
        let model = LibraryViewModel(libraryFeature: fixture.library)
        await model.load().value
        #expect(!model.isReady)
        #expect(model.books.isEmpty)
        #expect(model.errorMessage != nil)
        #expect(!model.isLoading)

        try validData.write(to: url)
        await model.load().value
        #expect(model.isReady)
        #expect(model.books.count == 3)
        #expect(model.errorMessage == nil)
    }

    @Test func balanceLoadsSavedTreasureAndReflectsNewGameplayCredits() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        _ = await fixture.progress.addDoubloons(12)
        let model = LibraryViewModel(libraryFeature: fixture.library)
        await model.load().value
        #expect(model.doubloonBalance == 12)
        let first = try #require(model.books.first)
        await fixture.game.start(book: first).value
        await fixture.game.recordCollectedDoubloons(2)?.value
        #expect(model.doubloonBalance == 14)
    }

    @Test func mapSelectionHonoursLocksAndReflectsCompletion() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let model = LibraryViewModel(libraryFeature: fixture.library)
        #expect(model.castles.isEmpty)
        #expect(model.selectedBook == nil)
        await model.load().value
        let first = try #require(model.books.first)
        let second = try #require(model.books.first { $0.id == "two" })
        model.select(second)
        #expect(model.selectedBook == nil)
        model.select(first)
        #expect(model.selectedBook?.id == "one")
        model.selectedBook = nil
        await fixture.library.recordCompletion(of: first.id)
        #expect(model.conqueredCount == 1)
        #expect(model.castles.map(\.number) == [1, 2, 3])
        model.select(second)
        #expect(model.selectedBook?.id == "two")
    }

    @Test func mapDoesNotCountCompletionsForRemovedBooks() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.progress.recordCompletion(of: "removed")
        let model = LibraryViewModel(libraryFeature: fixture.library)
        await model.load().value
        #expect(model.conqueredCount == 0)
        #expect(model.castles.map(\.isUnlocked) == [true, false, false])
    }
}
