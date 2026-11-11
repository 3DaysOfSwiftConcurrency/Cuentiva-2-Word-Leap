import Foundation
import Observation

@MainActor @Observable
final class WordLeapFeature {
    /// Artwork/profile catalogue only, not an inventory of unlocked characters.
    let characterProfiles = GameCharacter.cuentivaCast
    private let levelPlanBuilder: LevelPlanBuilder
    private let libraryFeature: LibraryFeature
    private(set) var activeLevel: LevelPlan?
    private(set) var preparationFailure: CastleAccessError?
    private(set) var landedWordCount = 0
    private(set) var isLevelComplete = false
    private(set) var runStatistics = AdventureRunStatistics()
    @ObservationIgnored private var preparationTask: Task<Void, Never>?
    // Completion must be saved before an immediate Next level request checks access.
    @ObservationIgnored private var completionTask: Task<Void, Never>?
    @ObservationIgnored private var doubloonSaveTask: Task<Void, Never>?
    private var preparationRequest: PreparationRequest?
    private var preparationRevision = 0
    private var completionRevision = 0
    private var doubloonSaveRevision = 0
    private var creditedLevelDoubloons = 0
    var collectedDoubloonCount: Int { creditedLevelDoubloons }
    var nextBook: StoryBook? {
        guard let currentBook = activeLevel?.book else { return nil }
        return libraryFeature.nextBook(after: currentBook)
    }
    var currentBookNumber: Int? {
        guard let currentBook = activeLevel?.book else { return nil }
        return libraryFeature.bookNumber(for: currentBook)
    }

    init(levelPlanBuilder: LevelPlanBuilder, libraryFeature: LibraryFeature) {
        self.levelPlanBuilder = levelPlanBuilder
        self.libraryFeature = libraryFeature
    }

    func startAdventure(with book: StoryBook, continuingRun: Bool = false) -> Task<Void, Never> {
        let request = PreparationRequest(bookID: book.id, continuingRun: continuingRun)
        if preparationRequest == request, let preparationTask { return preparationTask }
        preparationTask?.cancel()
        preparationRevision += 1
        let revision = preparationRevision
        preparationRequest = request
        preparationFailure = nil
        let newPreparationTask = Task { [levelPlanBuilder, libraryFeature, completionTask] in
            defer {
                if self.preparationRevision == revision {
                    self.preparationTask = nil
                    self.preparationRequest = nil
                }
            }
            do {
                await completionTask?.value
                try Task.checkCancellation()
                let playableBook = try await libraryFeature.bookForPlay(id: book.id)
                try Task.checkCancellation()
                let plan = await levelPlanBuilder.makePlan(for: playableBook)
                try Task.checkCancellation()
                guard self.preparationRevision == revision else { return }
                if !continuingRun { self.runStatistics = AdventureRunStatistics() }
                self.activeLevel = plan
                self.creditedLevelDoubloons = 0
                self.landedWordCount = 0
                self.isLevelComplete = false
            } catch let accessError as CastleAccessError {
                guard !Task.isCancelled, self.preparationRevision == revision else { return }
                self.preparationFailure = accessError
            } catch {
                guard !Task.isCancelled, self.preparationRevision == revision else { return }
                self.preparationFailure = .libraryUnavailable
            }
        }
        preparationTask = newPreparationTask
        return newPreparationTask
    }

    @discardableResult
    func recordLanding(at wordIndex: Int) -> Bool {
        guard let activeLevel, !isLevelComplete,
              activeLevel.words.indices.contains(wordIndex),
              wordIndex == landedWordCount else { return false }
        runStatistics.recordLanding(in: activeLevel, at: wordIndex)
        landedWordCount += 1
        isLevelComplete = landedWordCount == activeLevel.words.count
        if isLevelComplete {
            let bookID = activeLevel.book.id
            completionRevision += 1
            let revision = completionRevision
            let completionSaveTask = Task { [libraryFeature] in
                defer {
                    if self.completionRevision == revision {
                        self.completionTask = nil
                    }
                }
                await libraryFeature.recordCompletion(of: bookID)
            }
            completionTask = completionSaveTask
        }
        return true
    }

    @discardableResult
    func recordRunProgress(doubloons: Int, activeSeconds: Double) -> Int {
        guard let activeLevel else { return 0 }
        let collectedDoubloons = validatedDoubloonCount(doubloons, for: activeLevel)
        _ = recordCollectedDoubloons(collectedDoubloons)
        runStatistics.recordProgress(bookID: activeLevel.book.id,
            doubloons: collectedDoubloons, activeSeconds: activeSeconds)
        return creditedLevelDoubloons
    }

    /// The scene reports a cumulative count. Credit only its increase, including across retries.
    @discardableResult
    func recordCollectedDoubloons(_ reportedDoubloonCount: Int) -> Task<Void, Never>? {
        guard let activeLevel else { return doubloonSaveTask }
        let collectedDoubloons = validatedDoubloonCount(reportedDoubloonCount, for: activeLevel)
        let earnedDoubloons = collectedDoubloons - creditedLevelDoubloons
        guard earnedDoubloons > 0 else { return doubloonSaveTask }
        creditedLevelDoubloons = collectedDoubloons
        doubloonSaveRevision += 1
        let revision = doubloonSaveRevision
        let predecessor = doubloonSaveTask
        let doubloonCreditTask = Task { [libraryFeature] in
            defer {
                if self.doubloonSaveRevision == revision {
                    self.doubloonSaveTask = nil
                }
            }
            await predecessor?.value
            await libraryFeature.bankDoubloons(earnedDoubloons)
        }
        // Durable credits continue if the player leaves or begins another level.
        doubloonSaveTask = doubloonCreditTask
        return doubloonCreditTask
    }

    private func validatedDoubloonCount(_ reportedCount: Int, for level: LevelPlan) -> Int {
        min(max(0, reportedCount), min(30, level.words.count))
    }

    func endLevel() {
        preparationRevision += 1
        preparationTask?.cancel()
        preparationTask = nil
        preparationRequest = nil
        activeLevel = nil
        landedWordCount = 0
        isLevelComplete = false
    }
}

private struct PreparationRequest: Equatable {
    let bookID: String
    let continuingRun: Bool
}
