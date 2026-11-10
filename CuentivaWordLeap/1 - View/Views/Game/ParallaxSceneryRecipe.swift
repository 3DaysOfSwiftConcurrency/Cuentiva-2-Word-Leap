import Foundation
import CoreGraphics

/// The presentation recipe owns each environment's artwork, depth and density.
/// It contains no textures, physics, persistence or per-frame state.
struct ParallaxSceneryRecipe {
    enum Particles {
        case stars, fireflies, pollen, mist

        var particleCount: Int {
            switch self {
            case .stars: 56
            case .fireflies: 24
            case .pollen: 18
            case .mist: 16
            }
        }
    }

    struct Layer {
        let assetName: String
        let spriteCount: Int
        let edgeOffset: CGFloat
        let initialHeight: CGFloat
        let heightStep: CGFloat
        let width: CGFloat
        let speed: CGFloat
        let opacity: CGFloat
        let mirrorsAlternateSprites: Bool
    }

    let layers: [Layer]
    let particles: Particles

    var nodeCount: Int {
        1 + particles.particleCount + layers.reduce(0) { $0 + $1.spriteCount }
    }

    init(environment: BookEnvironment) {
        switch environment {
        case .coast: self.init(prefix: "Coast", particles: .mist)
        case .roots: self.init(prefix: "Roots", particles: .fireflies)
        case .railway: self.init(prefix: "Railway", particles: .mist)
        case .puddle: self.init(prefix: "Puddle", particles: .mist)
        case .observatory: self.init(prefix: "Observatory", particles: .stars)
        case .harbour: self.init(prefix: "Harbour", particles: .mist)
        case .theatre: self.init(prefix: "Theatre", particles: .fireflies)
        case .orchard: self.init(prefix: "Orchard", particles: .pollen)
        case .storm: self.init(prefix: "Storm", particles: .mist)
        case .letters: self.init(prefix: "Letters", particles: .fireflies)
        case .skyFalls:
            // Preserve the approved prototype's composition and motion.
            self.init(layers: [
                Layer(assetName: "SkyFallsIslet", spriteCount: 4, edgeOffset: 0.42,
                      initialHeight: -0.40, heightStep: 0.27, width: 0.24,
                      speed: 0.14, opacity: 0.62, mirrorsAlternateSprites: false),
                Layer(assetName: "SkyFallsIsland", spriteCount: 4, edgeOffset: 0.53,
                      initialHeight: -0.43, heightStep: 0.30, width: 0.43,
                      speed: 0.34, opacity: 1, mirrorsAlternateSprites: false),
                Layer(assetName: "SkyFallsCloud", spriteCount: 4, edgeOffset: 0.54,
                      initialHeight: -0.48, heightStep: 0.31, width: 0.60,
                      speed: 0.52, opacity: 0.82, mirrorsAlternateSprites: false)
            ], particles: .stars)
        }
    }

    private init(layers: [Layer], particles: Particles) {
        self.layers = layers
        self.particles = particles
    }

    private init(prefix: String, particles: Particles) {
        self.particles = particles
        layers = [
            Layer(assetName: prefix + "Landmark", spriteCount: 3, edgeOffset: 0.43,
                  initialHeight: -0.40, heightStep: 0.40, width: 0.30,
                  speed: 0.16, opacity: 0.85, mirrorsAlternateSprites: true),
            Layer(assetName: prefix + "Foreground", spriteCount: 4, edgeOffset: 0.53,
                  initialHeight: -0.46, heightStep: 0.31, width: 0.46,
                  speed: 0.38, opacity: 1, mirrorsAlternateSprites: true)
        ]
    }
}
