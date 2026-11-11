#if canImport(UIKit)
import Foundation
import SpriteKit
import Testing
@testable import CuentivaWordLeap

@MainActor
struct ParallaxBackgroundNodeTests {
    @Test func sceneryStaysBoundedAndNeverParticipatesInPhysics() {
        for environment in BookEnvironment.allCases {
            let background = ParallaxBackgroundNode(environment: environment, reduceMotion: false)
            background.layout(in: CGSize(width: 390, height: 844))
            let initialNodeCount = background.children.count
            #expect(count == ParallaxSceneryRecipe(environment: environment).nodeCount)
            for altitude in stride(from: CGFloat(0), through: 100_000, by: 250) {
                background.update(cameraClimb: altitude, activeSeconds: 30)
                #expect(background.children.count == initialNodeCount)
                #expect(background.children.allSatisfy { $0.physicsBody == nil && $0.position.y.isFinite })
            }
            background.layout(in: CGSize(width: 844, height: 390))
            #expect(background.children.count == initialNodeCount)
        }
    }

    @Test func reducedMotionFreezesPositionAndTwinkling() {
        for environment in BookEnvironment.allCases {
            let background = ParallaxBackgroundNode(environment: environment, reduceMotion: true)
            background.layout(in: CGSize(width: 390, height: 844))
            background.update(cameraClimb: 0, activeSeconds: 0)
            let positions = background.children.map(\.position)
            let opacity = background.children.map(\.alpha)
            background.update(cameraClimb: 9000, activeSeconds: 50)
            #expect(background.children.map(\.position) == positions)
            #expect(background.children.map(\.alpha) == opacity)
        }
    }

    @Test func everyPackMovesItsLayersAtTheirOwnDepth() throws {
        for environment in BookEnvironment.allCases {
            let background = ParallaxBackgroundNode(environment: environment, reduceMotion: false)
            background.layout(in: CGSize(width: 390, height: 844))
            for layer in ParallaxSceneryRecipe(environment: environment).layers {
                background.update(cameraClimb: 0, activeSeconds: 0)
                let sprite = try #require(background.childNode(withName: layer.assetName))
                let startingY = sprite.position.y
                background.update(cameraClimb: 100, activeSeconds: 1)
                #expect(abs(sprite.position.y - (startingY - 100 * layer.speed)) < 0.001)
            }
        }
    }

    @Test func eachPackRendersItsOwnSceneryAndKeepsBackdropStill() {
        for environment in BookEnvironment.allCases {
            let background = ParallaxBackgroundNode(environment: environment, reduceMotion: false)
            background.layout(in: CGSize(width: 390, height: 844))
            background.update(cameraClimb: 10_000, activeSeconds: 50)
            let expected = Set(ParallaxSceneryRecipe(environment: environment).layers.map(\.assetName))
                .union([environment.backdropAssetName])
            #expect(Set(background.children.compactMap(\.name)) == expected)
            #expect(background.children.first?.position == .zero)
        }
    }
}
#endif
