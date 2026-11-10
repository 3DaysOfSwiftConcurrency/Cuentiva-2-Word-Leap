import Foundation

/// Owns this adventure's totals across books and checkpoint retries, not a lifetime wallet.
struct AdventureRunStatistics: Sendable {
    private struct BookStatistics: Sendable {
        var platforms: Set<Int> = []
        var wordCount = 0
        var verbCount = 0
        var doubloonCount = 0
        var activeSeconds: TimeInterval = 0
        var isComplete = false
        var verbCountingAvailable = true
    }

    private var books: [String: BookStatistics] = [:]
    var levelsCompleted: Int { books.values.filter(\.isComplete).count }
    var platformsReached: Int { books.values.reduce(0) { $0 + $1.platforms.count } }
    var wordsCollected: Int { books.values.reduce(0) { $0 + $1.wordCount } }
    var verbsCollected: Int { books.values.reduce(0) { $0 + $1.verbCount } }
    var verbCountingAvailable: Bool { books.values.allSatisfy(\.verbCountingAvailable) }
    var doubloonsCollected: Int { books.values.reduce(0) { $0 + $1.doubloonCount } }
    var activeSeconds: TimeInterval { books.values.reduce(0) { $0 + $1.activeSeconds } }

    mutating func recordLanding(in plan: LevelPlan, at index: Int) {
        guard plan.words.indices.contains(index) else { return }
        var book = books[plan.book.id, default: BookStatistics()]
        guard book.platforms.insert(index).inserted else { return }
        if plan.words[index].contains(where: \.isLetter) {
            book.wordCount += 1
            if plan.verbIndices.contains(index) { book.verbCount += 1 }
        }
        book.verbCountingAvailable = book.verbCountingAvailable && plan.verbCountingAvailable
        book.isComplete = book.isComplete || index == plan.words.count - 1
        books[plan.book.id] = book
    }

    /// Receives cumulative level totals. Repeated callbacks cannot double-count rewards or time.
    mutating func recordProgress(bookID: String, doubloons: Int, activeSeconds: TimeInterval) {
        var book = books[bookID, default: BookStatistics()]
        book.doubloonCount = max(book.doubloonCount, min(30, max(0, doubloons)))
        if activeSeconds.isFinite { book.activeSeconds = max(book.activeSeconds, activeSeconds) }
        books[bookID] = book
    }
}
