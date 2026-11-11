import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct LibraryFeatureTests {
    @Test func remoteRefreshDoesNotBlockPlayFromTheBundledCatalogue() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let gate = RemoteManuscriptGate()
        let remoteManuscript = Data("@one|Pipa|Uno remoto|Remote One|A1\nHola.|Hello.\n".utf8)
        let bookRepository = CuentivaBookRepository(
            networkingManager: NetworkingManager { _ in await gate.request() },
            bundledLibraryURL: fixture.directory.appendingPathComponent("Library.dat")
        )
        let libraryFeature = LibraryFeature(bookRepository: bookRepository, levelProgressStore: fixture.levelProgressStore)
        await libraryFeature.load().value

        let refresh = libraryFeature.refresh()
        await gate.waitUntilRequested()
        let watchdog = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            gate.release(with: remoteManuscript)
        }
        defer {
            watchdog.cancel()
            gate.release(with: remoteManuscript)
        }

        let playableBook = try await libraryFeature.bookForPlay(id: "one")
        let refreshHadToBeReleased = gate.hasReleasedResponse
        #expect(playableBook.title == "Uno")
        #expect(!refreshHadToBeReleased)

        gate.release(with: remoteManuscript)
        await refresh.value
    }

    @Test func remoteRefreshQueuedDuringBundledLoadStillRuns() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let libraryURL = fixture.directory.appendingPathComponent("Library.dat")
        let remoteManuscript = Data("@one|Pipa|Uno remoto|Remote One|A1\nHola.|Hello.\n".utf8)
        let bookRepository = CuentivaBookRepository(
            networkingManager: NetworkingManager { _ in remoteManuscript },
            bundledLibraryURL: libraryURL
        )
        let libraryFeature = LibraryFeature(bookRepository: bookRepository, levelProgressStore: fixture.levelProgressStore)

        let bundledLoad = libraryFeature.load()
        let remoteRefresh = libraryFeature.refresh()
        await bundledLoad.value
        await remoteRefresh.value

        #expect(libraryFeature.books.map(\.title) == ["Uno remoto"])
        #expect(libraryFeature.requestFailure == nil)
        #expect(!libraryFeature.isLoading)
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
        let libraryFeature = LibraryFeature(bookRepository: CuentivaBookRepository(
            networkingManager: NetworkingManager(), bundledLibraryURL: url), levelProgressStore: fixture.levelProgressStore)
        await libraryFeature.load().value
        #expect(libraryFeature.castles.count == 52)
        #expect(libraryFeature.castles.map(\.number) == Array(1...52))
        for castle in libraryFeature.castles {
            #expect(libraryFeature.castles.filter { $0.isUnlocked && !$0.isCompleted }.map(\.id) == [castle.id])
            await libraryFeature.recordCompletion(of: castle.id).value
        }
        #expect(libraryFeature.castles.allSatisfy { $0.isUnlocked && $0.isCompleted })
    }

    @Test func newPlayerGetsNumberedCastlesWithOnlyTheFirstOpen() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        #expect(fixture.libraryFeature.castles.isEmpty)
        await fixture.libraryFeature.load().value
        #expect(fixture.libraryFeature.castles.map(\.number) == [1, 2, 3])
        #expect(fixture.libraryFeature.castles.map(\.isUnlocked) == [true, false, false])
        #expect(fixture.libraryFeature.castles.allSatisfy { !$0.isCompleted })
    }

    @Test func catalogueNavigationUsesCanonicalOrderAndRejectsUnknownBooks() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        let firstBook = try #require(fixture.libraryFeature.books.first)
        let secondBook = try #require(fixture.libraryFeature.books.dropFirst().first)
        let unknownBook = StoryBook(
            id: "unknown",
            storyteller: "Pipa",
            title: "Unknown",
            englishTitle: "Unknown",
            spanishPassages: ["Hola"]
        )

        #expect(fixture.libraryFeature.bookNumber(for: firstBook) == 1)
        #expect(fixture.libraryFeature.bookNumber(for: secondBook) == 2)
        #expect(fixture.libraryFeature.nextBook(after: firstBook) == secondBook)
        #expect(fixture.libraryFeature.bookNumber(for: unknownBook) == nil)
        #expect(fixture.libraryFeature.nextBook(after: unknownBook) == nil)
    }

    @Test func completionUnlocksOnlyTheNextCastleAndKeepsReplaysOpen() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        await fixture.libraryFeature.recordCompletion(of: "two").value
        #expect(fixture.libraryFeature.completedBookIDs.isEmpty)
        #expect(fixture.libraryFeature.castles.map(\.isUnlocked) == [true, false, false])
        await fixture.libraryFeature.recordCompletion(of: "one").value
        await fixture.libraryFeature.recordCompletion(of: "one").value
        #expect(fixture.libraryFeature.castles.map(\.isUnlocked) == [true, true, false])
        #expect(fixture.libraryFeature.completedBookIDs == ["one"])
        await fixture.libraryFeature.recordCompletion(of: "two").value
        #expect(fixture.libraryFeature.castles.map(\.isUnlocked) == [true, true, true])
        await fixture.libraryFeature.recordCompletion(of: "three").value
        let last = try #require(fixture.libraryFeature.books.last)
        #expect(fixture.libraryFeature.nextBook(after: last) == nil)
        #expect(fixture.libraryFeature.castles.allSatisfy { $0.isCompleted })
    }

    @Test func distinctCompletionCommandsExecuteInAdmissionOrder() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value

        let firstCompletion = fixture.libraryFeature.recordCompletion(of: "one")
        let secondCompletion = fixture.libraryFeature.recordCompletion(of: "two")
        await firstCompletion.value
        await secondCompletion.value

        #expect(fixture.libraryFeature.completedBookIDs == ["one", "two"])
        #expect(fixture.libraryFeature.castles.map(\.isUnlocked) == [true, true, true])
        #expect(await fixture.levelProgressStore.completedBookIDs() == ["one", "two"])
    }

    @Test func previouslyCompletedOutOfOrderCastlesRemainReplayable() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.levelProgressStore.recordCompletion(of: "three")
        await fixture.libraryFeature.load().value
        #expect(fixture.libraryFeature.castles.map(\.isUnlocked) == [true, false, true])
        #expect(fixture.libraryFeature.castles.map(\.isCompleted) == [false, false, true])
    }

    @Test func completionSurvivesANewFeatureGraphAndRefresh() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        await fixture.libraryFeature.recordCompletion(of: "one").value
        guard let restoredDefaults = UserDefaults(suiteName: fixture.suiteName) else {
            throw CocoaError(.fileReadUnknown)
        }
        let restored = LibraryFeature(bookRepository: fixture.bookRepository,
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
            networkingManager: NetworkingManager(), bundledLibraryURL: nil), levelProgressStore: fixture.levelProgressStore)
        await #expect(throws: CastleAccessError.self) { try await unavailable.bookForPlay(id: "one") }
        #expect(unavailable.castles.isEmpty)
        guard case .bundledLibrary? = unavailable.requestFailure else {
            Issue.record("Expected the bundled-library failure to remain available to presentation.")
            return
        }
        await #expect(throws: CastleAccessError.self) { try await fixture.libraryFeature.bookForPlay(id: "unknown") }
        await fixture.libraryFeature.recordCompletion(of: "unknown").value
        #expect(fixture.libraryFeature.completedBookIDs.isEmpty)
    }

    @Test func directAccessLoadsProgressAndReturnsOnlyTheCanonicalBook() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let first = try await fixture.libraryFeature.bookForPlay(id: "one")
        #expect(first.title == "Uno")
        await #expect(throws: CastleAccessError.self) { try await fixture.libraryFeature.bookForPlay(id: "two") }
        await fixture.levelProgressStore.recordCompletion(of: "one")
        let second = try await fixture.libraryFeature.bookForPlay(id: "two")
        #expect(second.title == "Dos")
    }
}

@MainActor
private final class RemoteManuscriptGate {
    private var requestStarted = false
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private var responseContinuation: CheckedContinuation<Data, Never>?
    private var releasedData: Data?
    private(set) var hasReleasedResponse = false

    func request() async -> Data {
        requestStarted = true
        let waiters = startedWaiters
        startedWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        if let releasedData { return releasedData }
        return await withCheckedContinuation { responseContinuation = $0 }
    }

    func waitUntilRequested() async {
        guard !requestStarted else { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func release(with data: Data) {
        guard !hasReleasedResponse else { return }
        hasReleasedResponse = true
        if let responseContinuation {
            self.responseContinuation = nil
            responseContinuation.resume(returning: data)
        } else {
            releasedData = data
        }
    }
}
