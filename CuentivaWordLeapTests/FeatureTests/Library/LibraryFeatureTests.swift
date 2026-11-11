import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct LibraryFeatureTests {
    @Test func remoteRefreshDoesNotBlockPlayFromTheBundledCatalogue() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let gate = RemoteManuscriptGate()
        let remoteManuscript = completeRemoteManuscript()
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

    @Test func cancellingTheOnlyWaiterKeepsTheSharedRefreshAliveWithoutAReplacement() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let gate = RemoteManuscriptGate()
        let remoteManuscript = completeRemoteManuscript()
        let bookRepository = CuentivaBookRepository(
            networkingManager: NetworkingManager { _ in await gate.request() },
            bundledLibraryURL: fixture.directory.appendingPathComponent("Library.dat")
        )
        let libraryFeature = LibraryFeature(
            bookRepository: bookRepository,
            levelProgressStore: fixture.levelProgressStore
        )
        await libraryFeature.load().value

        let screenWaiter = Task { await libraryFeature.refresh().value }
        await gate.waitUntilRequested()
        screenWaiter.cancel()
        let watchdog = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            gate.release(with: remoteManuscript)
        }
        defer {
            watchdog.cancel()
            gate.release(with: remoteManuscript)
        }

        gate.release(with: remoteManuscript)
        await screenWaiter.value

        #expect(gate.requestCount == 1)
        #expect(libraryFeature.books.map(\.title) == ["Uno remoto", "Dos remoto", "Tres remoto"])
        #expect(libraryFeature.requestFailure == nil)
    }

    @Test func laterEquivalentCallerJoinsTheSharedRefreshWithoutASecondRequest() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let gate = RemoteManuscriptGate()
        let remoteManuscript = completeRemoteManuscript()
        let libraryFeature = LibraryFeature(
            bookRepository: CuentivaBookRepository(
                networkingManager: NetworkingManager { _ in await gate.request() },
                bundledLibraryURL: fixture.directory.appendingPathComponent("Library.dat")
            ),
            levelProgressStore: fixture.levelProgressStore
        )
        await libraryFeature.load().value

        let firstWaiter = Task { await libraryFeature.refresh().value }
        await gate.waitUntilRequested()
        let laterRefresh = libraryFeature.refresh()
        firstWaiter.cancel()
        gate.release(with: remoteManuscript)
        await firstWaiter.value
        await laterRefresh.value

        #expect(gate.requestCount == 1)
        #expect(libraryFeature.books.map(\.title) == ["Uno remoto", "Dos remoto", "Tres remoto"])
        #expect(libraryFeature.requestFailure == nil)
    }

    @Test func remoteRefreshQueuedDuringBundledLoadStillRuns() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let libraryURL = fixture.directory.appendingPathComponent("Library.dat")
        let remoteManuscript = completeRemoteManuscript()
        let bookRepository = CuentivaBookRepository(
            networkingManager: NetworkingManager { _ in remoteManuscript },
            bundledLibraryURL: libraryURL
        )
        let libraryFeature = LibraryFeature(bookRepository: bookRepository, levelProgressStore: fixture.levelProgressStore)

        let bundledLoad = libraryFeature.load()
        let remoteRefresh = libraryFeature.refresh()
        await bundledLoad.value
        await remoteRefresh.value

        #expect(libraryFeature.books.map(\.title) == ["Uno remoto", "Dos remoto", "Tres remoto"])
        #expect(libraryFeature.requestFailure == nil)
        #expect(!libraryFeature.isLoading)
    }

    @Test func remoteRefreshOnAFreshFeatureEstablishesAReadyBundledBaseline() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let remoteManuscript = completeRemoteManuscript()
        let bookRepository = CuentivaBookRepository(
            networkingManager: NetworkingManager { _ in remoteManuscript },
            bundledLibraryURL: fixture.directory.appendingPathComponent("Library.dat")
        )
        let libraryFeature = LibraryFeature(
            bookRepository: bookRepository,
            levelProgressStore: fixture.levelProgressStore
        )

        await libraryFeature.refresh().value

        #expect(libraryFeature.isReady)
        #expect(libraryFeature.books.map(\.title) == ["Uno remoto", "Dos remoto", "Tres remoto"])
        #expect(libraryFeature.requestFailure == nil)
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
        let controlledProgressStore = ControlledLevelProgressStore(blockedBookID: "one")
        let libraryFeature = LibraryFeature(
            bookRepository: fixture.bookRepository,
            levelProgressStore: controlledProgressStore
        )
        await libraryFeature.load().value
        let barrierWatchdog = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await controlledProgressStore.releaseBlockedCommand()
        }
        defer { barrierWatchdog.cancel() }

        let firstCompletion = libraryFeature.recordCompletion(of: "one")
        await controlledProgressStore.waitUntilBlockedCommandIsAdmitted()
        let secondCompletion = libraryFeature.recordCompletion(of: "two")
        let requestsWhileFirstIsSuspended = await controlledProgressStore.completionRequests
        #expect(requestsWhileFirstIsSuspended == ["one"])

        await controlledProgressStore.releaseBlockedCommand()
        await firstCompletion.value
        await secondCompletion.value

        let savedBookIDs = await controlledProgressStore.completedBookIDs()
        let completionRequests = await controlledProgressStore.completionRequests
        let savedCompletionOrder = await controlledProgressStore.savedCompletionOrder
        #expect(libraryFeature.completedBookIDs == ["one", "two"])
        #expect(libraryFeature.castles.map(\.isUnlocked) == [true, true, true])
        #expect(savedBookIDs == ["one", "two"])
        #expect(completionRequests == ["one", "two"])
        #expect(savedCompletionOrder == ["one", "two"])
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

private func completeRemoteManuscript() -> Data {
    Data("""
    @one|Pipa|Uno remoto|Remote One|A1
    Hola.|Hello.
    @two|Musgo|Dos remoto|Remote Two|A1
    Corre.|Run.
    @three|Mora|Tres remoto|Remote Three|A1
    Mira.|Look.
    """.utf8)
}

private actor ControlledLevelProgressStore: LevelProgressStoring {
    private let blockedBookID: String
    private var savedCompletedBookIDs: Set<String> = []
    private var savedDoubloonBalance = 0
    private var blockedCommandContinuation: CheckedContinuation<Void, Never>?
    private var admissionWaiters: [CheckedContinuation<Void, Never>] = []
    private var isBlockedCommandReleased = false
    private(set) var completionRequests: [String] = []
    private(set) var savedCompletionOrder: [String] = []

    init(blockedBookID: String) {
        self.blockedBookID = blockedBookID
    }

    func completedBookIDs() -> Set<String> { savedCompletedBookIDs }

    func recordCompletion(of bookID: String) async {
        completionRequests.append(bookID)
        if bookID == blockedBookID, !isBlockedCommandReleased {
            let waiters = admissionWaiters
            admissionWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
            await withCheckedContinuation { blockedCommandContinuation = $0 }
        }
        savedCompletionOrder.append(bookID)
        savedCompletedBookIDs.insert(bookID)
    }

    func doubloonBalance() -> Int { savedDoubloonBalance }

    func addDoubloons(_ earnedDoubloons: Int) -> Int {
        savedDoubloonBalance += max(0, earnedDoubloons)
        return savedDoubloonBalance
    }

    func waitUntilBlockedCommandIsAdmitted() async {
        guard !completionRequests.contains(blockedBookID) else { return }
        await withCheckedContinuation { admissionWaiters.append($0) }
    }

    func releaseBlockedCommand() {
        isBlockedCommandReleased = true
        blockedCommandContinuation?.resume()
        blockedCommandContinuation = nil
        let waiters = admissionWaiters
        admissionWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }
}

@MainActor
private final class RemoteManuscriptGate {
    private var requestStarted = false
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private var responseContinuations: [CheckedContinuation<Data, Never>] = []
    private var releasedData: Data?
    private(set) var hasReleasedResponse = false
    private(set) var requestCount = 0

    func request() async -> Data {
        requestCount += 1
        requestStarted = true
        let waiters = startedWaiters
        startedWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        if let releasedData { return releasedData }
        return await withCheckedContinuation { responseContinuations.append($0) }
    }

    func waitUntilRequested() async {
        guard !requestStarted else { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func release(with data: Data) {
        guard !hasReleasedResponse else { return }
        hasReleasedResponse = true
        if responseContinuations.isEmpty {
            releasedData = data
        } else {
            let continuations = responseContinuations
            responseContinuations.removeAll()
            for continuation in continuations {
                continuation.resume(returning: data)
            }
        }
    }
}
