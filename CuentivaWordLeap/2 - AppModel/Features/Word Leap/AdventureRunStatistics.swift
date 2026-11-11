import Foundation

/// Owns this adventure's totals across books and checkpoint retries, not a lifetime wallet.
struct AdventureRunStatistics: Sendable {
    private struct BookStatistics: Sendable {
        var reachedPlatformIndices: Set<Int> = []
        var wordCount = 0
        var verbCount = 0
        var doubloonCount = 0
        var activeSeconds: TimeInterval = 0
        var isComplete = false
        var verbCountingAvailable = true
    }

    private var statisticsByBookID: [String: BookStatistics] = [:]
    var levelsCompleted: Int { statisticsByBookID.values.filter(\.isComplete).count }
    var platformsReached: Int {
        statisticsByBookID.values.reduce(0) { $0 + $1.reachedPlatformIndices.count }
    }
    var wordsCollected: Int { statisticsByBookID.values.reduce(0) { $0 + $1.wordCount } }
    var verbsCollected: Int { statisticsByBookID.values.reduce(0) { $0 + $1.verbCount } }
    var verbCountingAvailable: Bool { statisticsByBookID.values.allSatisfy(\.verbCountingAvailable) }
    var doubloonsCollected: Int { statisticsByBookID.values.reduce(0) { $0 + $1.doubloonCount } }
    var activeSeconds: TimeInterval { statisticsByBookID.values.reduce(0) { $0 + $1.activeSeconds } }

    mutating func recordLanding(in plan: LevelPlan, at index: Int) {
        guard plan.words.indices.contains(index) else { return }
        var statistics = statisticsByBookID[plan.book.id, default: BookStatistics()]
        guard statistics.reachedPlatformIndices.insert(index).inserted else { return }
        if plan.words[index].contains(where: \.isLetter) {
            statistics.wordCount += 1
            if plan.verbIndices.contains(index) { statistics.verbCount += 1 }
        }
        statistics.verbCountingAvailable = statistics.verbCountingAvailable && plan.verbCountingAvailable
        statistics.isComplete = statistics.isComplete || index == plan.words.count - 1
        statisticsByBookID[plan.book.id] = statistics
    }

    /// Receives cumulative level totals. Repeated callbacks cannot double-count rewards or time.
    mutating func recordProgress(bookID: String, doubloons: Int, activeSeconds: TimeInterval) {
        var statistics = statisticsByBookID[bookID, default: BookStatistics()]
        statistics.doubloonCount = max(statistics.doubloonCount, min(30, max(0, doubloons)))
        if activeSeconds.isFinite {
            statistics.activeSeconds = max(statistics.activeSeconds, activeSeconds)
        }
        statisticsByBookID[bookID] = statistics
    }
}
