import SpriteKit
import Foundation
import CoreGraphics

private enum ParallaxParticlePalette {
    static let starlight = SKColor(red: 1, green: 0.85, blue: 0.42, alpha: 1)
    static let fireflyGlow = SKColor(red: 0.85, green: 1, blue: 0.45, alpha: 1)
    static let pollenGlow = SKColor(red: 1, green: 0.9, blue: 0.65, alpha: 0.65)
    static let mist = SKColor(white: 0.9, alpha: 0.3)
}

/// Owns a bounded set of decorative sprites, attached to the gameplay camera.
/// It has no physics bodies and receives altitude rather than moving the camera.
final class ParallaxBackgroundNode: SKNode {
    private struct Scenery {
        let node: SKNode
        let initialY: CGFloat
        let height: CGFloat
        let speed: CGFloat
        let phase: CGFloat
        let twinkles: Bool
    }

    private let recipe: ParallaxSceneryRecipe
    private let reduceMotion: Bool
    private let backdrop: SKSpriteNode
    private var scenery: [Scenery] = []
    private var viewport: CGSize = .zero

    init(environment: BookEnvironment, reduceMotion: Bool) {
        recipe = ParallaxSceneryRecipe(environment: environment)
        self.reduceMotion = reduceMotion
        backdrop = SKSpriteNode(imageNamed: environment.backdropAssetName)
        super.init()
        zPosition = -100
        backdrop.name = environment.backdropAssetName
        addChild(backdrop)
    }

    required init?(coder: NSCoder) { nil }

    func layout(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        viewport = size
        let textureSize = backdrop.texture?.size() ?? CGSize(width: 1, height: 1)
        let scale = max(size.width / max(1, textureSize.width),
                        size.height / max(1, textureSize.height))
        backdrop.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        scenery.forEach { $0.node.removeFromParent() }
        scenery.removeAll()
        addParticles()
        for (depth, layer) in recipe.layers.enumerated() {
            for index in 0..<layer.spriteCount {
                let isLeft = index.isMultiple(of: 2)
                let side: CGFloat = isLeft ? -1 : 1
                addSprite(layer.assetName, x: side * size.width * layer.edgeOffset,
                          y: size.height * (layer.initialHeight + CGFloat(index) * layer.heightStep),
                          width: size.width * layer.width, speed: layer.speed,
                          depth: CGFloat(depth + 2), alpha: layer.opacity,
                          mirrored: !isLeft && layer.mirrorsAlternateSprites)
            }
        }
    }

    func update(cameraClimb: CGFloat, activeSeconds: TimeInterval) {
        for item in scenery {
            item.node.position.y = ParallaxLayout.verticalPosition(
                initialY: item.initialY, cameraClimb: cameraClimb, speed: item.speed,
                viewportHeight: viewport.height, spriteHeight: item.height, reduceMotion: reduceMotion)
            if item.twinkles {
                item.node.alpha = reduceMotion ? 0.65
                    : 0.60 + 0.22 * sin(CGFloat(activeSeconds) * 1.25 + item.phase)
            }
        }
    }

    private func addSprite(_ asset: String, x: CGFloat, y: CGFloat, width: CGFloat,
                           speed: CGFloat, depth: CGFloat, alpha: CGFloat, mirrored: Bool) {
        let sprite = SKSpriteNode(imageNamed: asset)
        sprite.name = asset
        let textureSize = sprite.texture?.size() ?? CGSize(width: 1, height: 1)
        sprite.size = CGSize(width: width, height: width * textureSize.height / max(1, textureSize.width))
        sprite.position = CGPoint(x: x, y: y)
        sprite.alpha = alpha
        sprite.zPosition = depth
        sprite.xScale = mirrored ? -1 : 1
        addChild(sprite)
        scenery.append(Scenery(node: sprite, initialY: y, height: sprite.size.height,
                               speed: speed, phase: 0, twinkles: false))
    }

    private func addParticles() {
        // Reusable vector sparkles avoid large transparent texture sheets.
        // Deterministic placement means retries and resizing do not reshuffle the sky.
        for index in 0..<recipe.particles.particleCount {
            let isSparkle = recipe.particles == .stars && index.isMultiple(of: 5)
            let radius: CGFloat = isSparkle ? 3.5 : 0.8
            let star: SKShapeNode
            if isSparkle {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: radius * 1.8))
                path.addLines(between: [
                    CGPoint(x: radius * 0.32, y: radius * 0.32),
                    CGPoint(x: radius, y: 0),
                    CGPoint(x: radius * 0.32, y: -radius * 0.32),
                    CGPoint(x: 0, y: -radius * 1.8),
                    CGPoint(x: -radius * 0.32, y: -radius * 0.32),
                    CGPoint(x: -radius, y: 0),
                    CGPoint(x: -radius * 0.32, y: radius * 0.32)
                ])
                path.closeSubpath()
                star = SKShapeNode(path: path)
                star.glowWidth = 2
            } else {
                star = SKShapeNode(circleOfRadius: radius)
            }
            switch recipe.particles {
            case .stars:
                star.fillColor = ParallaxParticlePalette.starlight
            case .fireflies:
                star.fillColor = ParallaxParticlePalette.fireflyGlow
                star.glowWidth = 2
            case .pollen:
                star.fillColor = ParallaxParticlePalette.pollenGlow
            case .mist:
                star.fillColor = ParallaxParticlePalette.mist
            }
            star.strokeColor = .clear
            let x = (CGFloat((index * 37 + 11) % 101) / 100 - 0.5) * viewport.width
            let y = (CGFloat((index * 61 + 7) % 103) / 102 - 0.5) * viewport.height
            star.position = CGPoint(x: x, y: y)
            star.zPosition = 1
            addChild(star)
            scenery.append(Scenery(node: star, initialY: y, height: radius * 4,
                                   speed: isSparkle ? 0.10 : 0.05,
                                   phase: CGFloat(index) * 1.7, twinkles: true))
        }
    }
}
