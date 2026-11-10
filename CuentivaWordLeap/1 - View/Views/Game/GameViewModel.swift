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
    var preparationError: String? { wordLeapFeature.preparationFailure?.localizedDescription }
    var wordsRead: Int { wordLeapFeature.landedWordCount }
    var activeWordCount: Int { activeLevel?.words.count ?? currentBook.platformCount }
    var loadingCharacterAssetName: String { currentBook.characterProfile?.spriteAssetName ?? "WordLeapMora" }
    var platformProgress: String { "\(wordsRead) / \(activeWordCount) platforms" }
    var collectedDoubloonText: String { "\(collectedDoubloons)" }
    var collectedDoubloonAccessibilityLabel: String { "\(collectedDoubloons) doubloons collected" }
    var completionDoubloonText: String { "\(collectedDoubloons) doubloons collected" }
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
        let seconds = Int(stats.activeSeconds)
        return [
            GameStatistic(title: "Levels completed", value: "\(stats.levelsCompleted)", symbol: "flag.checkered"),
            GameStatistic(title: "Platforms reached", value: "\(stats.platformsReached)", symbol: "square.stack.3d.up.fill"),
            GameStatistic(title: "Doubloons", value: "\(stats.doubloonsCollected)", symbol: "doubloon"),
            GameStatistic(title: "Time played", value: String(format: "%d:%02d", seconds / 60, seconds % 60),
                symbol: "clock.fill", detail: "minutes : seconds"),
            GameStatistic(title: "Words collected", value: "\(stats.wordsCollected)", symbol: "textformat.abc"),
            GameStatistic(title: "Verbs recognised", value: stats.verbCountingAvailable ? "\(stats.verbsCollected)" : "—",
                symbol: "text.book.closed.fill", detail: stats.verbCountingAvailable ? "vocabulary estimate" : "unavailable")
        ]
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
            scene = WordLeapScene(size: CGSize(width: 390, height: 740), levelPlan: level,
                reduceMotion: reduceMotion,
                reportCoinCount: { [weak self] count in self?.recordCollectedDoubloons(count) },
                reportRescue: { [weak self] coins, seconds in self?.showCompletedBook(coins: coins, seconds: seconds) },
                reportDeath: { [weak self] coins, seconds in self?.showDeath(coins: coins, seconds: seconds) },
                reportLanding: { [weak self] index, word in self?.recordLanding(at: index, word: word) })
        }
        preparationTask = task
        return task
    }

    func startNextLevel() {
        guard let nextBook else { return }
        _ = prepare(nextBook, reduceMotion: reduceMotion, continuingRun: true)
    }

    func recordLanding(at wordIndex: Int, word: String) {
        wordLeapFeature.recordLanding(at: wordIndex)
        lastReadWord = word
    }

    func showDeath(coins: Int, seconds: TimeInterval) {
        wordLeapFeature.recordRunProgress(doubloons: coins, activeSeconds: seconds)
        collectedDoubloons = coins
        isDeathPresented = true
    }

    private func recordCollectedDoubloons(_ count: Int) {
        collectedDoubloons = count
        wordLeapFeature.recordCollectedDoubloons(count)
    }

    private func showCompletedBook(coins: Int, seconds: TimeInterval) {
        wordLeapFeature.recordRunProgress(doubloons: coins, activeSeconds: seconds)
        collectedDoubloons = coins
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
        wordLeapFeature.endLevel()
    }
}

private struct GamePreparationRequest: Equatable {
    let bookID: String
    let reduceMotion: Bool
    let continuingRun: Bool
}
