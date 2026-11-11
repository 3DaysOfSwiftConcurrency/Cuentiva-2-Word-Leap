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
        let task = Task { [levelPlanBuilder, libraryFeature, completionTask] in
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
        preparationTask = task
        return task
    }

    func recordLanding(at wordIndex: Int) {
        guard let activeLevel, !isLevelComplete, activeLevel.words.indices.contains(wordIndex) else { return }
        runStatistics.recordLanding(in: activeLevel, at: wordIndex)
        landedWordCount = max(landedWordCount, wordIndex + 1)
        isLevelComplete = landedWordCount == activeLevel.words.count
        if isLevelComplete {
            let bookID = activeLevel.book.id
            completionRevision += 1
            let revision = completionRevision
            let task = Task { [libraryFeature] in
                defer {
                    if self.completionRevision == revision {
                        self.completionTask = nil
                    }
                }
                await libraryFeature.recordCompletion(of: bookID)
            }
            completionTask = task
        }
    }

    func recordRunProgress(doubloons: Int, activeSeconds: Double) {
        guard let activeLevel else { return }
        let collectedDoubloons = validatedDoubloonCount(doubloons, for: activeLevel)
        _ = recordCollectedDoubloons(collectedDoubloons)
        runStatistics.recordProgress(bookID: activeLevel.book.id,
            doubloons: collectedDoubloons, activeSeconds: activeSeconds)
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
        let task = Task { [libraryFeature] in
            defer {
                if self.doubloonSaveRevision == revision {
                    self.doubloonSaveTask = nil
                }
            }
            await predecessor?.value
            await libraryFeature.bankDoubloons(earnedDoubloons)
        }
        // Durable credits continue if the player leaves or begins another level.
        doubloonSaveTask = task
        return task
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
