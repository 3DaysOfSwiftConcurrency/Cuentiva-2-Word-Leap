import Testing
@testable import CuentivaWordLeap

@MainActor
struct AdventureRunFeatureTests {
    @Test func nextLevelKeepsRunTotalsButFreshAdventureResetsThem() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let wordLeapFeature = fixture.wordLeapFeature
        await fixture.libraryFeature.load().value
        let first = try #require(fixture.libraryFeature.books.first)
        let second = try #require(fixture.libraryFeature.books.first { $0.id == "two" })
        await wordLeapFeature.start(book: first).value
        let plan = try #require(wordLeapFeature.activeLevel)
        for index in plan.words.indices { wordLeapFeature.recordLanding(at: index) }
        let firstWordCount = wordLeapFeature.runStatistics.wordsCollected
        wordLeapFeature.recordRunProgress(doubloons: 3, activeSeconds: 75)
        await wordLeapFeature.start(book: second, continuingRun: true).value
        wordLeapFeature.recordLanding(at: 0)
        wordLeapFeature.recordRunProgress(doubloons: 2, activeSeconds: 10)
        #expect(wordLeapFeature.runStatistics.wordsCollected == firstWordCount + 1)
        #expect(wordLeapFeature.runStatistics.doubloonsCollected == 5)
        #expect(wordLeapFeature.runStatistics.activeSeconds == 85)
        wordLeapFeature.endLevel()
        await wordLeapFeature.start(book: first).value
        #expect(wordLeapFeature.runStatistics.wordsCollected == 0)
        #expect(wordLeapFeature.runStatistics.activeSeconds == 0)
    }
}
