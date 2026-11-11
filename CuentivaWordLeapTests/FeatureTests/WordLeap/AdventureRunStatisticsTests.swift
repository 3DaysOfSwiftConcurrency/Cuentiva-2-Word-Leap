import Testing
@testable import CuentivaWordLeap

struct AdventureRunStatisticsTests {
    @Test func reachingOnlyTheFinalPlatformDoesNotCompleteTheLevel() {
        let plan = fixture()
        var stats = AdventureRunStatistics()

        stats.recordLanding(in: plan, at: plan.words.count - 1)
        #expect(stats.levelsCompleted == 0)

        for index in plan.words.indices.dropLast() {
            stats.recordLanding(in: plan, at: index)
        }
        #expect(stats.levelsCompleted == 1)
    }

    @Test func countsWordsAndVerbsWithoutCountingPunctuationOrRepeatLandings() {
        let plan = fixture()
        var stats = AdventureRunStatistics()
        for index in [0, 1, 2, 2, 3, -1, 99] { stats.recordLanding(in: plan, at: index) }
        #expect(stats.platformsReached == 4)
        #expect(stats.wordsCollected == 3)
        #expect(stats.verbsCollected == 1)
        #expect(stats.levelsCompleted == 1)
    }

    @Test func retryTotalsAreMonotonicAndNextBooksAccumulate() {
        var stats = AdventureRunStatistics()
        stats.recordProgress(bookID: "one", doubloons: 7, activeSeconds: 61)
        stats.recordProgress(bookID: "one", doubloons: 7, activeSeconds: 61)
        stats.recordProgress(bookID: "one", doubloons: 3, activeSeconds: 20)
        #expect(stats.doubloonsCollected == 7)
        #expect(stats.activeSeconds == 61)
        stats.recordProgress(bookID: "one", doubloons: 10, activeSeconds: 90)
        stats.recordProgress(bookID: "two", doubloons: 2, activeSeconds: 12)
        for index in 0..<4 { stats.recordLanding(in: fixture(), at: index) }
        stats.recordLanding(in: fixture(id: "two"), at: 0)
        #expect(stats.doubloonsCollected == 12)
        #expect(stats.activeSeconds == 102)
        #expect(stats.levelsCompleted == 1)
        #expect(stats.platformsReached == 5)
    }

    @Test func invalidProgressCannotCorruptTotals() {
        var stats = AdventureRunStatistics()
        stats.recordProgress(bookID: "one", doubloons: -3, activeSeconds: -.infinity)
        #expect(stats.doubloonsCollected == 0)
        #expect(stats.activeSeconds == 0)
        stats.recordProgress(bookID: "one", doubloons: 99, activeSeconds: .nan)
        #expect(stats.doubloonsCollected == 30)
        #expect(stats.activeSeconds == 0)
    }

    private func fixture(id: String = "one") -> LevelPlan {
        let book = StoryBook(id: id, storyteller: "Pipa", title: "Pipa salta", englishTitle: "Pipa jumps",
            spanishPassages: ["Pipa salta alto."])
        return LevelPlan(book: book, words: ["Pipa", "salta", "alto", "."], verbIndices: [1])
    }
}
