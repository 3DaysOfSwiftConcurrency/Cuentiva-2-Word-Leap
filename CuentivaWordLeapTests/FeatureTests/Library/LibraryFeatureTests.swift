import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct LibraryFeatureTests {
    @Test func remoteRefreshQueuedDuringBundledLoadStillRuns() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let libraryURL = fixture.directory.appendingPathComponent("Library.dat")
        let remoteManuscript = Data("@one|Pipa|Uno remoto|Remote One|A1\nHola.|Hello.\n".utf8)
        let repository = CuentivaBookRepository(
            networkingManager: NetworkingManager { _ in remoteManuscript },
            bundledLibraryURL: libraryURL
        )
        let library = LibraryFeature(bookRepository: repository, levelProgressStore: fixture.progress)

        let bundledLoad = library.load()
        let remoteRefresh = library.refresh()
        await bundledLoad.value
        await remoteRefresh.value

        #expect(library.books.map(\.title) == ["Uno remoto"])
        #expect(library.loadError == nil)
        #expect(!library.isLoading)
    }

    @Test func allBundledCastlesUnlockInNumberedOrder() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        let url = try #require(bundle.url(forResource: "Library", withExtension: "dat"))
        let library = LibraryFeature(bookRepository: CuentivaBookRepository(
            networkingManager: NetworkingManager(), bundledLibraryURL: url), levelProgressStore: fixture.progress)
        await library.load().value
        #expect(library.castles.count == 52)
        #expect(library.castles.map(\.number) == Array(1...52))
        for castle in library.castles {
            #expect(library.castles.filter { $0.isUnlocked && !$0.isCompleted }.map(\.id) == [castle.id])
            await library.recordCompletion(of: castle.id)
        }
        #expect(library.castles.allSatisfy { $0.isUnlocked && $0.isCompleted })
    }

    @Test func newPlayerGetsNumberedCastlesWithOnlyTheFirstOpen() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        #expect(fixture.library.castles.isEmpty)
        await fixture.library.load().value
        #expect(fixture.library.castles.map(\.number) == [1, 2, 3])
        #expect(fixture.library.castles.map(\.isUnlocked) == [true, false, false])
        #expect(fixture.library.castles.allSatisfy { !$0.isCompleted })
    }

    @Test func completionUnlocksOnlyTheNextCastleAndKeepsReplaysOpen() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        await fixture.library.recordCompletion(of: "one")
        await fixture.library.recordCompletion(of: "one")
        #expect(fixture.library.castles.map(\.isUnlocked) == [true, true, false])
        #expect(fixture.library.completedBookIDs == ["one"])
        await fixture.library.recordCompletion(of: "two")
        #expect(fixture.library.castles.map(\.isUnlocked) == [true, true, true])
        await fixture.library.recordCompletion(of: "three")
        let last = try #require(fixture.library.books.last)
        #expect(fixture.library.nextBook(after: last) == nil)
        #expect(fixture.library.castles.allSatisfy { $0.isCompleted })
    }

    @Test func previouslyCompletedOutOfOrderCastlesRemainReplayable() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.progress.recordCompletion(of: "three")
        await fixture.library.load().value
        #expect(fixture.library.castles.map(\.isUnlocked) == [true, false, true])
        #expect(fixture.library.castles.map(\.isCompleted) == [false, false, true])
    }

    @Test func completionSurvivesANewFeatureGraphAndRefresh() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.library.load().value
        await fixture.library.recordCompletion(of: "one")
        guard let restoredDefaults = UserDefaults(suiteName: fixture.suiteName) else {
            throw CocoaError(.fileReadUnknown)
        }
        let restored = LibraryFeature(bookRepository: fixture.repository,
            levelProgressStore: LevelProgressStore(defaults: restoredDefaults))
        await restored.load().value
        await restored.refreshProgress().value
        #expect(restored.castles.map(\.isUnlocked) == [true, true, false])
        #expect(restored.completedBookIDs == ["one"])
    }

    @Test func missingCatalogueAndUnknownBooksAreDenied() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let unavailable = LibraryFeature(bookRepository: CuentivaBookRepository(
            networkingManager: NetworkingManager(), bundledLibraryURL: nil), levelProgressStore: fixture.progress)
        await #expect(throws: CastleAccessError.self) { try await unavailable.bookForPlay(id: "one") }
        #expect(unavailable.castles.isEmpty)
        #expect(unavailable.loadError != nil)
        await #expect(throws: CastleAccessError.self) { try await fixture.library.bookForPlay(id: "unknown") }
        await fixture.library.recordCompletion(of: "unknown")
        #expect(fixture.library.completedBookIDs.isEmpty)
    }

    @Test func directAccessLoadsProgressAndReturnsOnlyTheCanonicalBook() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let first = try await fixture.library.bookForPlay(id: "one")
        #expect(first.title == "Uno")
        await #expect(throws: CastleAccessError.self) { try await fixture.library.bookForPlay(id: "two") }
        await fixture.progress.recordCompletion(of: "one")
        let second = try await fixture.library.bookForPlay(id: "two")
        #expect(second.title == "Dos")
    }
}
