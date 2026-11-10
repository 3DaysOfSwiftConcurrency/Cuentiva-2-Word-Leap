import Foundation
import CoreGraphics
import Testing
@testable import CuentivaWordLeap

struct ParallaxSceneryRecipeTests {
    @Test func everyEnvironmentHasItsOwnCompleteLayeredPack() {
        var usedAssets: Set<String> = []
        for environment in BookEnvironment.allCases {
            let recipe = ParallaxSceneryRecipe(environment: environment)
            #expect(recipe.layers.count >= 2)
            #expect(recipe.nodeCount <= 69)
            #expect(recipe.particles.particleCount > 0)
            for layer in recipe.layers {
                #expect(usedAssets.insert(layer.assetName).inserted)
                #expect(layer.assetName != environment.backdropAssetName)
                #expect(layer.spriteCount > 0 && layer.spriteCount <= 4)
            }
        }
    }

    @Test func foregroundMovesFasterAndCentralGameplayCorridorStaysClear() {
        for environment in BookEnvironment.allCases {
            let recipe = ParallaxSceneryRecipe(environment: environment)
            var previousSpeed: CGFloat = 0
            for layer in recipe.layers {
                #expect(layer.speed > previousSpeed && layer.speed < 1)
                previousSpeed = layer.speed
                // Even full rectangular texture bounds stay out of the central 46%.
                #expect(layer.edgeOffset - layer.width / 2 >= 0.23)
                #expect(layer.opacity > 0 && layer.opacity <= 1)
            }
        }
    }

    @Test func atmosphereMatchesTheBookSetting() {
        #expect(ParallaxSceneryRecipe(environment: .observatory).particles == .stars)
        #expect(ParallaxSceneryRecipe(environment: .roots).particles == .fireflies)
        #expect(ParallaxSceneryRecipe(environment: .orchard).particles == .pollen)
        #expect(ParallaxSceneryRecipe(environment: .puddle).particles == .mist)
    }

    @Test func approvedSkyFallsDepthAndDensityArePreserved() {
        let recipe = ParallaxSceneryRecipe(environment: .skyFalls)
        #expect(recipe.nodeCount == 69)
        #expect(recipe.layers.map(\.speed) == [0.14, 0.34, 0.52])
        #expect(recipe.layers.map(\.assetName) == ["SkyFallsIslet", "SkyFallsIsland", "SkyFallsCloud"])
    }
}
