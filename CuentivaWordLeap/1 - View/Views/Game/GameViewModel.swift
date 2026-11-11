import Observation
import Foundation
import CoreGraphics

@MainActor @Observable
final class GameViewModel {
    private let selectedBook: StoryBook
    private let wordLeapFeature: WordLeapFeature
    private let libraryFeature: LibraryFeature
    private var reduceMotion = false
    @ObservationIgnored private var preparationTask: Task<Void, Never>?
    private var preparationRequest: GamePreparationRequest?
    private var preparationRevision = 0
    private var activeSceneID: UUID?
    private(set) var scene: WordLeapScene?
    private(set) var isBookRevealed = false
    private(set) var collectedDoubloons = 0
    private(set) var lastReadWord = ""
    private(set) var isDeathPresented = false

    init(
        book: StoryBook,
        wordLeapFeature: WordLeapFeature = AppModel.shared.wordLeapFeature,
        libraryFeature: LibraryFeature = AppModel.shared.libraryFeature
    ) {
        selectedBook = book
        self.wordLeapFeature = wordLeapFeature
        self.libraryFeature = libraryFeature
    }

    var activeLevel: LevelPlan? { wordLeapFeature.activeLevel }
    var currentBook: StoryBook { activeLevel?.book ?? selectedBook }
    var preparationError: String? {
        switch wordLeapFeature.preparationFailure {
        case .libraryUnavailable:
            "The adventure could not be loaded. Return to the map and try again."
        case .unknownBook:
            "This book is no longer on the adventure map."
        case .locked(let previousCastle):
            "Complete Castle \(previousCastle) to unlock this adventure."
        case nil:
            nil
        }
    }
    var wordsRead: Int { wordLeapFeature.landedWordCount }
    var activeWordCount: Int { activeLevel?.words.count ?? currentBook.platformCount }
    var loadingCharacterAssetName: String { currentBook.characterProfile?.spriteAssetName ?? "WordLeapMora" }
    var platformProgress: String {
        "\(wordsRead) / \(activeWordCount) \(activeWordCount == 1 ? "platform" : "platforms")"
    }
    var collectedDoubloonText: String { "\(collectedDoubloons)" }
    var collectedDoubloonAccessibilityLabel: String {
        "\(collectedDoubloons) \(collectedDoubloons == 1 ? "doubloon" : "doubloons") collected"
    }
    var completionDoubloonText: String { collectedDoubloonAccessibilityLabel }
    var completionActionTitle: String { nextBook == nil ? "Adventure" : "Next level" }
    var completedBookCover: CompletedBookCoverPresentation {
        CompletedBookCoverPresentation(book: currentBook)
    }
    var readingCardText: String {
        lastReadWord.isEmpty ? "Touch to jump. Hold left or right to steer." : lastReadWord
    }
    var isLevelComplete: Bool { preparationError == nil && wordLeapFeature.isLevelComplete }
    var gameOverStatistics: [GameStatistic] {
        let stats = wordLeapFeature.runStatistics
        return [
            GameStatistic(title: "Levels completed", displayValue: "\(stats.levelsCompleted)", symbol: "flag.checkered"),
            GameStatistic(title: "Platforms reached", displayValue: "\(stats.platformsReached)", symbol: "square.stack.3d.up.fill"),
            GameStatistic(title: "Doubloons", displayValue: "\(stats.doubloonsCollected)", symbol: "doubloon"),
            GameStatistic(title: "Time played",
                displayValue: elapsedTimeText(for: stats.activeSeconds),
                symbol: "clock.fill", detail: "minutes : seconds"),
            GameStatistic(title: "Words collected", displayValue: "\(stats.wordsCollected)", symbol: "textformat.abc"),
            GameStatistic(title: "Verbs recognised",
                displayValue: stats.verbCountingAvailable ? "\(stats.verbsCollected)" : "—",
                symbol: "text.book.closed.fill", detail: stats.verbCountingAvailable ? "vocabulary estimate" : "unavailable")
        ]
    }

    private func elapsedTimeText(for activeSeconds: TimeInterval) -> String {
        guard activeSeconds.isFinite else { return "—" }
        // Leave headroom below Int.max before converting untrusted or corrupt persisted values.
        let maximumSafeWholeSeconds = Int.max / 60
        let boundedSeconds = min(max(0, activeSeconds), Double(maximumSafeWholeSeconds))
        let wholeSeconds = Int(boundedSeconds)
        let secondText = String(format: "%02d", wholeSeconds % 60)
        return "\(wholeSeconds / 60):\(secondText)"
    }

    var nextBook: StoryBook? {
        guard let book = activeLevel?.book else { return nil }
        return libraryFeature.nextBook(after: book)
    }

    var completionTitle: String {
        guard let book = activeLevel?.book, let number = libraryFeature.bookNumber(for: book) else {
            return "Book completed!"
        }
        return "Book \(number) completed!"
    }

    func prepare(reduceMotion: Bool = false) -> Task<Void, Never> {
        prepare(selectedBook, reduceMotion: reduceMotion)
    }

    func prepare(_ book: StoryBook, reduceMotion: Bool = false, continuingRun: Bool = false) -> Task<Void, Never> {
        let request = GamePreparationRequest(
            bookID: book.id,
            reduceMotion: reduceMotion,
            continuingRun: continuingRun
        )
        if preparationRequest == request, let preparationTask { return preparationTask }
        self.reduceMotion = reduceMotion
        preparationTask?.cancel()
        preparationRevision += 1
        let revision = preparationRevision
        preparationRequest = request
        scene?.removeAllActions()
        scene = nil
        activeSceneID = nil
        lastReadWord = ""
        isDeathPresented = false
        isBookRevealed = false
        collectedDoubloons = 0
        let task = Task {
            defer {
                if preparationRevision == revision {
                    preparationTask = nil
                    preparationRequest = nil
                }
            }
            await wordLeapFeature.start(book: book, continuingRun: continuingRun).value
            guard !Task.isCancelled, preparationRevision == revision,
                  preparationError == nil, let level = activeLevel,
                  level.book.id == book.id else { return }
            let sceneID = UUID()
            activeSceneID = sceneID
            scene = WordLeapScene(size: CGSize(width: 390, height: 740), levelPlan: level,
                reduceMotion: reduceMotion,
                reportCoinCount: { [weak self] collectedDoubloonCount in
                    guard let self, activeSceneID == sceneID else { return }
                    recordCollectedDoubloons(collectedDoubloonCount)
                },
                reportRescue: { [weak self] collectedDoubloons, activeSeconds in
                    guard let self, activeSceneID == sceneID else { return }
                    showCompletedBook(collectedDoubloons: collectedDoubloons, activeSeconds: activeSeconds)
                },
                reportDeath: { [weak self] collectedDoubloons, activeSeconds in
                    guard let self, activeSceneID == sceneID else { return }
                    showDeath(collectedDoubloons: collectedDoubloons, activeSeconds: activeSeconds)
                },
                reportLanding: { [weak self] wordIndex, word in
                    guard let self, activeSceneID == sceneID else { return }
                    recordLanding(at: wordIndex, word: word)
                })
        }
        preparationTask = task
        return task
    }

    @discardableResult
    func startNextLevel() -> Task<Void, Never>? {
        guard let nextBook else { return nil }
        return prepare(nextBook, reduceMotion: reduceMotion, continuingRun: true)
    }

    func recordLanding(at wordIndex: Int, word: String) {
        wordLeapFeature.recordLanding(at: wordIndex)
        lastReadWord = word
    }

    func showDeath(collectedDoubloons: Int, activeSeconds: TimeInterval) {
        wordLeapFeature.recordRunProgress(doubloons: collectedDoubloons, activeSeconds: activeSeconds)
        self.collectedDoubloons = collectedDoubloons
        isDeathPresented = true
    }

    private func recordCollectedDoubloons(_ reportedDoubloonCount: Int) {
        collectedDoubloons = reportedDoubloonCount
        wordLeapFeature.recordCollectedDoubloons(reportedDoubloonCount)
    }

    private func showCompletedBook(collectedDoubloons: Int, activeSeconds: TimeInterval) {
        wordLeapFeature.recordRunProgress(doubloons: collectedDoubloons, activeSeconds: activeSeconds)
        self.collectedDoubloons = collectedDoubloons
        isBookRevealed = true
    }
    func dismissDeath() { isDeathPresented = false }

    func retry() {
        scene?.retryFromCheckpoint()
        dismissDeath()
    }

    func leaveLevel() {
        isDeathPresented = false
        preparationRevision += 1
        preparationTask?.cancel()
        preparationTask = nil
        preparationRequest = nil
        scene?.removeAllActions()
        scene = nil
        activeSceneID = nil
        wordLeapFeature.endLevel()
    }
}

private struct GamePreparationRequest: Equatable {
    let bookID: String
    let reduceMotion: Bool
    let continuingRun: Bool
}
