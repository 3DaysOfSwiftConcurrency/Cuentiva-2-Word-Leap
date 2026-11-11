import Foundation
import CoreGraphics
import Testing
@testable import CuentivaWordLeap

struct WordLeapSimulationTests {
    @Test func coinsRequireContactAndRemainCollectedAfterRetryAndResize() {
        let words = Array(repeating: "historia", count: 200)
        var simulation = WordLeapSimulation(words: words, viewport: CGSize(width: 420, height: 912))
        #expect(simulation.coins.count == 30)
        #expect(simulation.collectedCoins.isEmpty)
        _ = simulation.launch()
        _ = simulation.advance(delta: 1.0 / 60, steeringTargetX: nil)
        #expect(simulation.collectedCoins == [0])
        simulation.resetToCheckpoint()
        _ = simulation.launch()
        _ = simulation.advance(delta: 1.0 / 60, steeringTargetX: nil)
        #expect(simulation.collectedCoins == [0])
        let resized = WordLeapSimulation(words: words, viewport: CGSize(width: 852, height: 393),
            checkpointIndex: simulation.furthestPlatformIndex, collectedCoins: simulation.collectedCoins)
        #expect(resized.collectedCoins == [0])
        #expect(resized.coins.count == 30)
    }

    @Test func shortAndEmptyBooksHaveNoDuplicateCoinPlacements() {
        let short = WordLeapSimulation(words: ["Hola", "."], viewport: CGSize(width: 390, height: 844))
        #expect(short.coins.count == 2)
        let empty = WordLeapSimulation(words: [], viewport: CGSize(width: 390, height: 844))
        #expect(empty.coins.isEmpty)
    }

    @Test func deathPausesUntilExplicitRetryAndKeepsCheckpoint() throws {
        var simulation = WordLeapSimulation(words: ["En", "este", "mercado"],
            viewport: CGSize(width: 420, height: 912), checkpointIndex: 1)
        let checkpoint = simulation.platforms[1]
        _ = simulation.launch()
        var deathNotifications = 0
        for _ in 0..<600 {
            _ = simulation.advance(delta: 1.0 / 60, steeringTargetX: 420)
            if simulation.detectFall(below: checkpoint.frame.minY - 300) { deathNotifications += 1 }
        }
        #expect(simulation.isDead)
        #expect(deathNotifications == 1)
        #expect(simulation.furthestPlatformIndex == 1)
        let fallenPosition = simulation.position
        #expect(simulation.launch() == nil)
        _ = simulation.advance(delta: 1, steeringTargetX: 0)
        #expect(simulation.position == fallenPosition)

        simulation.resetToCheckpoint()
        #expect(!simulation.isDead)
        #expect(simulation.isWaitingForLaunch)
        #expect(simulation.furthestPlatformIndex == 1)
        #expect(simulation.position == CGPoint(x: checkpoint.frame.midX,
            y: checkpoint.frame.maxY + WordLeapSimulation.footOffset))
        _ = simulation.launch()
        #expect(!simulation.isWaitingForLaunch)
        #expect(simulation.verticalVelocity > 0)
    }

    @Test func spawnRemainsSupportedUntilTouch() throws {
        var simulation = WordLeapSimulation(words: ["En", "este", "mercado"], viewport: CGSize(width: 420, height: 912))
        let first = try #require(simulation.platforms.first)
        let spawn = simulation.position
        for _ in 0..<600 { _ = simulation.advance(delta: 1.0 / 60, steeringTargetX: 0) }
        #expect(simulation.position == spawn)
        #expect(simulation.position.x == first.frame.midX)
        #expect(abs(simulation.position.y - WordLeapSimulation.footOffset - first.frame.maxY) < 0.000001)
        #expect(simulation.isWaitingForLaunch)
    }

    @Test(arguments: [30, 60, 120])
    func topEdgeContactBouncesInsteadOfFallingThrough(fps: Int) throws {
        var simulation = WordLeapSimulation(words: ["En", "este", "mercado"], viewport: CGSize(width: 420, height: 912))
        let first = try #require(simulation.platforms.first)
        #expect(simulation.launch() == 0)
        var bounces = 0
        for _ in 0..<(fps * 8) {
            let velocity = simulation.verticalVelocity
            _ = simulation.advance(delta: 1.0 / Double(fps), steeringTargetX: nil)
            if velocity < 0, simulation.verticalVelocity > 0 { bounces += 1 }
            #expect(simulation.position.y - WordLeapSimulation.footOffset >= first.frame.maxY - 0.001)
        }
        #expect(bounces > 3)
    }

    @Test func checkpointAndResizeRemainSupported() throws {
        var simulation = WordLeapSimulation(words: ["En", "este", "mercado"],
            viewport: CGSize(width: 420, height: 912), checkpointIndex: 1)
        _ = simulation.launch()
        for _ in 0..<180 { _ = simulation.advance(delta: 1.0 / 60, steeringTargetX: 420) }
        simulation.resetToCheckpoint()
        let checkpoint = simulation.platforms[simulation.furthestPlatformIndex]
        #expect(simulation.position.x == checkpoint.frame.midX)
        #expect(simulation.position.y == checkpoint.frame.maxY + WordLeapSimulation.footOffset)
        #expect(simulation.isWaitingForLaunch)
        let resized = WordLeapSimulation(words: simulation.platforms.map(\.word),
            viewport: CGSize(width: 852, height: 393), checkpointIndex: simulation.furthestPlatformIndex)
        #expect(resized.position.x == resized.platforms[resized.furthestPlatformIndex].frame.midX)
        #expect(resized.isWaitingForLaunch)
    }

    @Test(arguments: [30, 60, 120])
    func everyBundledBookCanBeCompletedWithReactionTime(fps: Int) throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        let url = try #require(bundle.url(forResource: "stories", withExtension: "txt"))
        let books = try CuentivaBookRepository.decode(Data(contentsOf: url))
        #expect(!books.isEmpty)
        for size in [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844),
                     CGSize(width: 420, height: 912), CGSize(width: 852, height: 393),
                     CGSize(width: 1024, height: 1366)] {
            for book in books {
                let words = book.spanishPassages.flatMap(SpanishWordTokenizer.platformTokens)
                var simulation = WordLeapSimulation(words: words, viewport: size)
                _ = simulation.launch()
                for platform in simulation.platforms {
                    #expect(platform.frame.minX >= 0 && platform.frame.maxX <= size.width)
                }
                for destination in simulation.platforms.dropFirst() {
                    // Allow a human reaction delay at the beginning of each jump.
                    var landed: Int?
                    for frame in 0..<(fps * 2) {
                        let target = Double(frame) / Double(fps) < Double(WordLeapSimulation.steeringGracePeriod)
                            ? nil : destination.frame.midX
                        if let index = simulation.advance(delta: 1.0 / Double(fps), steeringTargetX: target) {
                            landed = index
                            break
                        }
                    }
                    try #require(landed == destination.index,
                        "Unreachable word \(destination.index) in \(book.id), \(size), \(fps) fps")
                }
                #expect(simulation.furthestPlatformIndex == words.count - 1)
                #expect(simulation.coins.count == min(30, words.count))
                #expect(simulation.collectedCoins.count >= min(25, words.count),
                    "Too few coins on the playable route in \(book.id)")
                #expect(simulation.isWaitingForLaunch)
                let diedAfterCompletion = simulation.detectFall(below: simulation.position.y + 1)
                #expect(!diedAfterCompletion)
            }
        }
    }
}
