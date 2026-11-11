import Testing
@testable import CuentivaWordLeap

@MainActor
struct CastleAccessTests {
    @Test func lockedAndUnknownLevelsCannotStartOrChangeRunTotals() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        let second = try #require(fixture.libraryFeature.books.first { $0.id == "two" })
        await fixture.wordLeapFeature.startAdventure(with: second).value
        #expect(fixture.wordLeapFeature.activeLevel == nil)
        #expect(fixture.wordLeapFeature.preparationFailure == .locked(previousCastle: 1))
        #expect(fixture.wordLeapFeature.runStatistics.wordsCollected == 0)
        let unknown = StoryBook(id: "unknown", storyteller: "Pipa", title: "", englishTitle: "", spanishPassages: ["X"])
        await fixture.wordLeapFeature.startAdventure(with: unknown).value
        #expect(fixture.wordLeapFeature.activeLevel == nil)
        #expect(fixture.wordLeapFeature.preparationFailure == .unknownBook)
        #expect(await fixture.levelProgressStore.completedBookIDs().isEmpty)
    }

    @Test func partialPlayStaysLockedButImmediateNextLevelWaitsForCompletion() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        let first = try #require(fixture.libraryFeature.books.first)
        let second = try #require(fixture.libraryFeature.books.first { $0.id == "two" })
        await fixture.wordLeapFeature.startAdventure(with: first).value
        fixture.wordLeapFeature.recordLanding(at: 0)
        fixture.wordLeapFeature.recordRunProgress(doubloons: 2, activeSeconds: 12)
        await fixture.wordLeapFeature.startAdventure(with: second, continuingRun: true).value
        #expect(fixture.wordLeapFeature.activeLevel?.book.id == "one")
        #expect(fixture.wordLeapFeature.preparationFailure == .locked(previousCastle: 1))
        #expect(fixture.wordLeapFeature.runStatistics.doubloonsCollected == 2)
        #expect(!fixture.libraryFeature.canPlay(second))
        let plan = try #require(fixture.wordLeapFeature.activeLevel)
        for index in plan.words.indices { fixture.wordLeapFeature.recordLanding(at: index) }
        await fixture.wordLeapFeature.startAdventure(with: second, continuingRun: true).value
        #expect(fixture.wordLeapFeature.preparationFailure == nil)
        #expect(fixture.wordLeapFeature.activeLevel?.book.id == "two")
        #expect(fixture.wordLeapFeature.runStatistics.doubloonsCollected == 2)
        #expect(fixture.libraryFeature.canPlay(second))
        #expect(await fixture.levelProgressStore.completedBookIDs() == ["one"])
    }

    @Test func leavingDoesNotCancelEarnedUnlockAndSuppliedBookCannotBypassCatalogue() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let forged = StoryBook(id: "one", storyteller: "Pipa", title: "", englishTitle: "", spanishPassages: ["X"])
        await fixture.wordLeapFeature.startAdventure(with: forged).value
        let plan = try #require(fixture.wordLeapFeature.activeLevel)
        #expect(plan.book.title == "Uno")
        #expect(plan.words.count > 1)
        for index in plan.words.indices { fixture.wordLeapFeature.recordLanding(at: index) }
        fixture.wordLeapFeature.endLevel()
        let second = try #require(fixture.libraryFeature.books.first { $0.id == "two" })
        await fixture.wordLeapFeature.startAdventure(with: second).value
        #expect(fixture.wordLeapFeature.activeLevel?.book.id == "two")
        #expect(await fixture.levelProgressStore.completedBookIDs() == ["one"])
    }

    @Test func cancelledPreparationDoesNotStartOrUnlockACastle() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        let first = try #require(fixture.libraryFeature.books.first)
        let cancelledPreparation = fixture.wordLeapFeature.startAdventure(with: first)
        fixture.wordLeapFeature.endLevel()
        await cancelledPreparation.value
        #expect(fixture.wordLeapFeature.activeLevel == nil)
        #expect(fixture.libraryFeature.completedBookIDs.isEmpty)
        await fixture.wordLeapFeature.startAdventure(with: first).value
        #expect(fixture.wordLeapFeature.activeLevel?.book.id == first.id)
    }

    @Test func obsoletePreparationCannotPublishOrClearItsPendingReplacement() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        await fixture.libraryFeature.load().value
        await fixture.libraryFeature.recordCompletion(of: "one").value
        let first = try #require(fixture.libraryFeature.books.first { $0.id == "one" })
        let second = try #require(fixture.libraryFeature.books.first { $0.id == "two" })
        let controlledBuilder = ControlledLevelPlanBuilder()
        let wordLeapFeature = WordLeapFeature(
            levelPlanBuilder: controlledBuilder,
            libraryFeature: fixture.libraryFeature
        )

        let obsoletePreparation = wordLeapFeature.startAdventure(with: first)
        await controlledBuilder.waitUntilRequested(bookID: first.id)
        let currentPreparation = wordLeapFeature.startAdventure(with: second)
        await controlledBuilder.waitUntilRequested(bookID: second.id)

        await controlledBuilder.release(bookID: first.id)
        await obsoletePreparation.value
        let joinedCurrentPreparation = wordLeapFeature.startAdventure(with: second)
        let secondRequestCount = await controlledBuilder.requestCount(for: second.id)
        #expect(secondRequestCount == 1)

        await controlledBuilder.release(bookID: second.id)
        await currentPreparation.value
        await joinedCurrentPreparation.value

        #expect(wordLeapFeature.activeLevel?.book.id == second.id)
        #expect(wordLeapFeature.preparationFailure == nil)
    }
}

private actor ControlledLevelPlanBuilder: LevelPlanBuilding {
    private var requestCounts: [String: Int] = [:]
    private var requestWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var planWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var releasedBookIDs: Set<String> = []

    func makePlan(for book: StoryBook) async -> LevelPlan {
        requestCounts[book.id, default: 0] += 1
        let waiters = requestWaiters.removeValue(forKey: book.id) ?? []
        for waiter in waiters { waiter.resume() }
        if !releasedBookIDs.contains(book.id) {
            await withCheckedContinuation { planWaiters[book.id, default: []].append($0) }
        }
        return LevelPlan(book: book, words: book.spanishPassages.flatMap(SpanishWordTokenizer.platformTokens))
    }

    func waitUntilRequested(bookID: String) async {
        guard requestCounts[bookID, default: 0] == 0 else { return }
        await withCheckedContinuation { requestWaiters[bookID, default: []].append($0) }
    }

    func release(bookID: String) {
        releasedBookIDs.insert(bookID)
        let waiters = planWaiters.removeValue(forKey: bookID) ?? []
        for waiter in waiters { waiter.resume() }
    }

    func requestCount(for bookID: String) -> Int {
        requestCounts[bookID, default: 0]
    }
}
