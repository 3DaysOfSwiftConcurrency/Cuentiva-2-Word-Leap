import Foundation
import Observation

@MainActor @Observable
final class LibraryFeature {
    private let bookRepository: CuentivaBookRepository
    private let levelProgressStore: LevelProgressStore
    private(set) var books: [StoryBook] = []
    private(set) var completedBookIDs: Set<String> = []
    private(set) var doubloonBalance = 0
    private(set) var requestFailure: LibraryRequestFailure?
    private(set) var isLoading = false
    private(set) var isReady = false
    @ObservationIgnored private var loadingTask: Task<Void, Never>?
    @ObservationIgnored private var progressRefreshTask: Task<Void, Never>?
    private var loadingOperation: LibraryLoadingOperation?
    private var loadingRevision = 0

    init(bookRepository: CuentivaBookRepository, levelProgressStore: LevelProgressStore) {
        self.bookRepository = bookRepository
        self.levelProgressStore = levelProgressStore
    }

    var castles: [AdventureCastle] {
        books.enumerated().map { index, book in
            let completed = completedBookIDs.contains(book.id)
            let previousCompleted = index == 0 || completedBookIDs.contains(books[index - 1].id)
            return AdventureCastle(book: book, number: index + 1, isCompleted: completed,
                isUnlocked: completed || previousCompleted)
        }
    }

    var conqueredCastleCount: Int { castles.filter(\.isCompleted).count }

    func canPlay(_ book: StoryBook) -> Bool {
        castles.first { $0.id == book.id }?.isUnlocked == true
    }

    /// Every gameplay entry point uses the same policy and the canonical catalogue book.
    func bookForPlay(id: String) async throws -> StoryBook {
        if books.isEmpty { await load().value }
        if let loadingTask { await loadingTask.value }
        guard !books.isEmpty else { throw CastleAccessError.libraryUnavailable }
        await refreshProgress().value
        guard let castle = castles.first(where: { $0.id == id }) else {
            throw CastleAccessError.unknownBook
        }
        guard castle.isUnlocked else {
            throw CastleAccessError.locked(previousCastle: castle.number - 1)
        }
        return castle.book
    }

    func recordCompletion(of bookID: String) async {
        guard books.contains(where: { $0.id == bookID }) else { return }
        await levelProgressStore.recordCompletion(of: bookID)
        completedBookIDs.insert(bookID)
    }

    func load() -> Task<Void, Never> {
        if let loadingTask { return loadingTask }
        return beginLoading(.bundled, after: nil)
    }

    func refresh() -> Task<Void, Never> {
        if loadingOperation == .remote, let loadingTask { return loadingTask }
        return beginLoading(.remote, after: loadingTask)
    }

    private func beginLoading(
        _ operation: LibraryLoadingOperation,
        after predecessor: Task<Void, Never>?
    ) -> Task<Void, Never> {
        loadingRevision += 1
        let revision = loadingRevision
        loadingOperation = operation
        isLoading = true
        let task = Task { [bookRepository, levelProgressStore] in
            defer {
                if self.loadingRevision == revision {
                    self.isLoading = false
                    self.loadingTask = nil
                    self.loadingOperation = nil
                }
            }
            await predecessor?.value
            switch operation {
            case .bundled:
                await self.loadBooks(from: bookRepository, levelProgressStore: levelProgressStore)
            case .remote:
                await self.refreshBooks(from: bookRepository, levelProgressStore: levelProgressStore)
            }
        }
        loadingTask = task
        return task
    }

    func refreshProgress() -> Task<Void, Never> {
        if let progressRefreshTask { return progressRefreshTask }
        let task = Task { [levelProgressStore] in
            async let completed = levelProgressStore.completedBookIDs()
            async let balance = levelProgressStore.doubloonBalance()
            completedBookIDs.formUnion(await completed)
            doubloonBalance = max(doubloonBalance, await balance)
            progressRefreshTask = nil
        }
        progressRefreshTask = task
        return task
    }

    func bankDoubloons(_ earnedDoubloons: Int) async {
        let savedBalance = await levelProgressStore.addDoubloons(earnedDoubloons)
        // Treasure only increases; a late read must not overwrite a newer credit.
        doubloonBalance = max(doubloonBalance, savedBalance)
    }

    private func refreshDoubloonBalance() async {
        let savedBalance = await levelProgressStore.doubloonBalance()
        doubloonBalance = max(doubloonBalance, savedBalance)
    }

    func nextBook(after book: StoryBook) -> StoryBook? {
        guard let index = books.firstIndex(where: { $0.id == book.id }), index + 1 < books.count else { return nil }
        return books[index + 1]
    }

    func bookNumber(for book: StoryBook) -> Int? {
        books.firstIndex(where: { $0.id == book.id }).map { $0 + 1 }
    }

    private func loadBooks(
        from repository: CuentivaBookRepository,
        levelProgressStore: LevelProgressStore
    ) async {
        do {
            async let catalogue = repository.books()
            async let completed = levelProgressStore.completedBookIDs()
            async let balance = levelProgressStore.doubloonBalance()
            let snapshot = try await (catalogue, completed, balance)
            // Publish the first presentation together, never briefly show zero progress.
            books = snapshot.0
            completedBookIDs.formUnion(snapshot.1)
            doubloonBalance = max(doubloonBalance, snapshot.2)
            requestFailure = nil
            isReady = true
        }
        catch { requestFailure = .bundledLibrary(error) }
    }

    private func refreshBooks(
        from repository: CuentivaBookRepository,
        levelProgressStore: LevelProgressStore
    ) async {
        await refreshDoubloonBalance()
        do {
            books = try await repository.refreshFromGitHub()
            completedBookIDs.formUnion(await levelProgressStore.completedBookIDs())
            requestFailure = nil
        }
        catch { requestFailure = .remoteRefresh(error) }
    }
}

private enum LibraryLoadingOperation: Equatable {
    case bundled
    case remote
}

enum LibraryRequestFailure: Error {
    case bundledLibrary(any Error)
    case remoteRefresh(any Error)
}
