import CoreGraphics
import Testing
@testable import CuentivaWordLeap

struct ActivePlayTimeTests {
    @Test func onlyActiveGameplayAddsTimeAndRetryPreservesIt() {
        var simulation = WordLeapSimulation(words: ["Pipa", "salta", "."], viewport: CGSize(width: 390, height: 844))
        _ = simulation.advance(delta: 1, steeringTargetX: nil)
        #expect(simulation.activeSeconds == 0)
        _ = simulation.launch()
        _ = simulation.advance(delta: 0.02, steeringTargetX: nil)
        #expect(simulation.activeSeconds == 0.02)
        let died = simulation.detectFall(below: simulation.position.y + 1)
        #expect(died)
        _ = simulation.advance(delta: 60, steeringTargetX: nil)
        #expect(simulation.activeSeconds == 0.02)
        simulation.resetToCheckpoint()
        _ = simulation.advance(delta: 60, steeringTargetX: nil)
        #expect(simulation.activeSeconds == 0.02)
        _ = simulation.launch()
        _ = simulation.advance(delta: 0.02, steeringTargetX: nil)
        #expect(simulation.activeSeconds == 0.04)
        let resized = WordLeapSimulation(words: ["Pipa", "salta", "."], viewport: CGSize(width: 844, height: 390),
            checkpointIndex: simulation.furthestPlatformIndex, activeSeconds: simulation.activeSeconds)
        #expect(resized.activeSeconds == simulation.activeSeconds)
    }
}
