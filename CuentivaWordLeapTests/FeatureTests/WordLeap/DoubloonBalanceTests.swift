import Testing
@testable import CuentivaWordLeap

@MainActor
struct DoubloonBalanceTests {
    @Test func duplicateAndLowerCountsDoNotCreditTheSameCoinsAgain() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        let book = try #require(fixture.libraryFeature.books.first)
        await fixture.wordLeapFeature.startAdventure(with: book).value
        await fixture.wordLeapFeature.recordCollectedDoubloons(2)?.value
        await fixture.wordLeapFeature.recordCollectedDoubloons(2)?.value
        await fixture.wordLeapFeature.recordCollectedDoubloons(1)?.value
        await fixture.wordLeapFeature.recordCollectedDoubloons(-1)?.value
        fixture.wordLeapFeature.recordRunProgress(doubloons: 2, activeSeconds: 10)
        await fixture.wordLeapFeature.recordCollectedDoubloons(2)?.value
        #expect(fixture.libraryFeature.doubloonBalance == 2)
        await fixture.wordLeapFeature.recordCollectedDoubloons(3)?.value
        #expect(fixture.libraryFeature.doubloonBalance == 3)
    }

    @Test func earnedCoinsSurviveLeavingAndFreshAdventuresCanEarnMore() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        let book = try #require(fixture.libraryFeature.books.first)
        await fixture.wordLeapFeature.startAdventure(with: book).value
        let credit = fixture.wordLeapFeature.recordCollectedDoubloons(2)
        fixture.wordLeapFeature.endLevel()
        await credit?.value
        #expect(await fixture.levelProgressStore.doubloonBalance() == 2)
        await fixture.wordLeapFeature.startAdventure(with: book).value
        await fixture.wordLeapFeature.recordCollectedDoubloons(1)?.value
        #expect(fixture.libraryFeature.doubloonBalance == 3)
    }

    @Test func inactiveGamesAndCountsAboveAvailableCoinsCannotInflateBalance() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.wordLeapFeature.recordCollectedDoubloons(30)?.value
        #expect(fixture.libraryFeature.doubloonBalance == 0)
        await fixture.libraryFeature.load().value
        let book = try #require(fixture.libraryFeature.books.first)
        await fixture.wordLeapFeature.startAdventure(with: book).value
        let level = try #require(fixture.wordLeapFeature.activeLevel)
        await fixture.wordLeapFeature.recordCollectedDoubloons(100)?.value
        let availableDoubloons = min(30, level.words.count)
        #expect(fixture.libraryFeature.doubloonBalance == availableDoubloons)
        fixture.wordLeapFeature.recordRunProgress(doubloons: 100, activeSeconds: 1)
        #expect(fixture.wordLeapFeature.runStatistics.doubloonsCollected == availableDoubloons)
    }

    @Test func overlappingCreditsAndRefreshKeepTheNewestBalance() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        let book = try #require(fixture.libraryFeature.books.first)
        await fixture.wordLeapFeature.startAdventure(with: book).value
        let first = fixture.wordLeapFeature.recordCollectedDoubloons(1)
        let refresh = fixture.libraryFeature.refreshProgress()
        let second = fixture.wordLeapFeature.recordCollectedDoubloons(2)
        let third = fixture.wordLeapFeature.recordCollectedDoubloons(3)
        await first?.value
        await refresh.value
        await second?.value
        await third?.value
        #expect(fixture.libraryFeature.doubloonBalance == 3)
        #expect(await fixture.levelProgressStore.doubloonBalance() == 3)
    }
}
