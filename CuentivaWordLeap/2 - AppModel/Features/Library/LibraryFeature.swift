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
    @ObservationIgnored private var completionSaveTask: Task<Void, Never>?
    private var loadingOperation: LibraryLoadingOperation?
    private var loadingRevision = 0
    private var completionSaveRevision = 0

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

    /// Completion commands are durable and execute in admission order across persistence.
    @discardableResult
    func recordCompletion(of bookID: String) -> Task<Void, Never> {
        completionSaveRevision += 1
        let revision = completionSaveRevision
        let predecessor = completionSaveTask
        let saveTask = Task { [levelProgressStore] in
            defer {
                if self.completionSaveRevision == revision {
                    self.completionSaveTask = nil
                }
            }
            await predecessor?.value
            guard let book = self.books.first(where: { $0.id == bookID }), self.canPlay(book) else {
                return
            }
            await levelProgressStore.recordCompletion(of: bookID)
            self.completedBookIDs.insert(bookID)
        }
        completionSaveTask = saveTask
        return saveTask
    }

    func load() -> Task<Void, Never> {
        if let loadingTask { return loadingTask }
        return enqueueLoadingOperation(.bundled, after: nil)
    }

    func refresh() -> Task<Void, Never> {
        if loadingOperation == .remote, let loadingTask { return loadingTask }
        let bundledLoad = books.isEmpty ? load() : loadingTask
        return enqueueLoadingOperation(.remote, after: bundledLoad)
    }

    private func enqueueLoadingOperation(
        _ operation: LibraryLoadingOperation,
        after predecessor: Task<Void, Never>?
    ) -> Task<Void, Never> {
        loadingRevision += 1
        let revision = loadingRevision
        loadingOperation = operation
        isLoading = true
        let operationTask = Task { [bookRepository, levelProgressStore] in
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
        loadingTask = operationTask
        return operationTask
    }

    func refreshProgress() -> Task<Void, Never> {
        if let progressRefreshTask { return progressRefreshTask }
        let refreshTask = Task { [levelProgressStore] in
            async let savedCompletedBookIDs = levelProgressStore.completedBookIDs()
            async let savedDoubloonBalance = levelProgressStore.doubloonBalance()
            completedBookIDs.formUnion(await savedCompletedBookIDs)
            doubloonBalance = max(doubloonBalance, await savedDoubloonBalance)
            progressRefreshTask = nil
        }
        progressRefreshTask = refreshTask
        return refreshTask
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
            async let catalogueRequest = repository.books()
            async let completedBookIDsRequest = levelProgressStore.completedBookIDs()
            async let doubloonBalanceRequest = levelProgressStore.doubloonBalance()
            let (loadedBooks, savedCompletedBookIDs, savedDoubloonBalance) = try await (
                catalogueRequest,
                completedBookIDsRequest,
                doubloonBalanceRequest
            )
            // Publish the first presentation together, never briefly show zero progress.
            books = loadedBooks
            completedBookIDs.formUnion(savedCompletedBookIDs)
            doubloonBalance = max(doubloonBalance, savedDoubloonBalance)
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
            let refreshedBooks = try await repository.refreshFromGitHub()
            let savedCompletedBookIDs = await levelProgressStore.completedBookIDs()
            books = refreshedBooks
            completedBookIDs.formUnion(savedCompletedBookIDs)
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
