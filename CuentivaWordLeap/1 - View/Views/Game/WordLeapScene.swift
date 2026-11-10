import SpriteKit
import UIKit
import SwiftUI

final class WordLeapScene: SKScene {
    private let levelPlan: LevelPlan
    private let reportLanding: @MainActor (_ wordIndex: Int, _ word: String) -> Void
    private let reportDeath: @MainActor (Int, TimeInterval) -> Void
    private let reportCoinCount: @MainActor (Int) -> Void
    private let reportRescue: @MainActor (Int, TimeInterval) -> Void
    private let reduceMotion: Bool
    private var isRescuing = false
    private var coinNodes: [Int: SKSpriteNode] = [:]
    private let player = SKSpriteNode(imageNamed: "WordLeapHero")
    private let cameraNode = SKCameraNode()
    private let scenery: ParallaxBackgroundNode
    private let platformLayer = SKNode()
    private var simulation: WordLeapSimulation
    private var steeringTargetX: CGFloat?
    private var lastUpdateTime: TimeInterval = 0

    init(
        size: CGSize,
        levelPlan: LevelPlan,
        reduceMotion: Bool = false,
        reportCoinCount: @escaping @MainActor (Int) -> Void,
        reportRescue: @escaping @MainActor (Int, TimeInterval) -> Void,
        reportDeath: @escaping @MainActor (Int, TimeInterval) -> Void,
        reportLanding: @escaping @MainActor (_ wordIndex: Int, _ word: String) -> Void
    ) {
        self.levelPlan = levelPlan
        scenery = ParallaxBackgroundNode(environment: levelPlan.book.environment, reduceMotion: reduceMotion)
        self.reportLanding = reportLanding
        self.reportDeath = reportDeath
        self.reportCoinCount = reportCoinCount
        self.reportRescue = reportRescue
        self.reduceMotion = reduceMotion
        simulation = WordLeapSimulation(words: levelPlan.words, viewport: size)
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        guard cameraNode.parent == nil else { return }
        backgroundColor = SKColor(red: 0.03, green: 0.10, blue: 0.26, alpha: 1)
        addChild(cameraNode)
        camera = cameraNode
        cameraNode.addChild(scenery)
        addChild(platformLayer)
        addPlayer()
        layoutWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard cameraNode.parent != nil, !isRescuing, !simulation.isDead,
              size.width > 0, size.height > 0 else { return }
        layoutWorld()
    }

    private func layoutWorld() {
        // With a camera, (0, 0) is the centre of the viewport, not its lower-left.
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        scenery.layout(in: size)
        platformLayer.removeAllChildren()
        simulation = WordLeapSimulation(words: levelPlan.words, viewport: size,
            checkpointIndex: simulation.furthestPlatformIndex, collectedCoins: simulation.collectedCoins,
            activeSeconds: simulation.activeSeconds)
        makePlatforms()
        makeCoins()
        returnToCheckpoint()
        updateScenery()
        lastUpdateTime = 0
    }

    private func makeCoins() {
        coinNodes.removeAll()
        let renderer = ImageRenderer(content: DoubloonArtwork(size: 48))
        renderer.scale = 2
        guard let image = renderer.uiImage else { return }
        let texture = SKTexture(image: image)
        for (index, position) in simulation.coins where !simulation.collectedCoins.contains(index) {
            let coin = SKSpriteNode(texture: texture)
            coin.size = CGSize(width: 30, height: 30)
            coin.position = position
            coin.zPosition = 8
            if !reduceMotion {
                coin.run(.repeatForever(.sequence([
                    .scaleX(to: 0.65, duration: 0.65), .scaleX(to: 1, duration: 0.65)
                ])))
            }
            platformLayer.addChild(coin)
            coinNodes[index] = coin
        }
    }

    private func showCollectedCoins() {
        let collected = coinNodes.keys.filter { simulation.collectedCoins.contains($0) }
        guard !collected.isEmpty else { return }
        for index in collected {
            guard let coin = coinNodes.removeValue(forKey: index) else { continue }
            coin.removeAllActions()
            coin.run(.sequence([.group([
                .moveBy(x: 0, y: 35, duration: 0.25), .scale(to: 1.5, duration: 0.25),
                .fadeOut(withDuration: 0.25)
            ]), .removeFromParent()]))
        }
        let collectedDoubloonCount = simulation.collectedCoins.count
        Task { @MainActor in reportCoinCount(collectedDoubloonCount) }
    }

    private func addPlayer() {
        player.size = CGSize(width: 72, height: 72)
        player.zPosition = 20
        addChild(player)
    }

    private func makePlatforms() {
        for definition in simulation.platforms {
            let platform = makePlatform(word: definition.word, index: definition.index, frame: definition.frame)
            platformLayer.addChild(platform)
        }
    }

    private func makePlatform(word: String, index: Int, frame: CGRect) -> SKNode {
        let container = SKNode()
        let shadow = SKShapeNode(rect: frame.offsetBy(dx: 0, dy: -8), cornerRadius: 24)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.28)
        shadow.strokeColor = .clear
        container.addChild(shadow)

        let island = SKShapeNode(rect: frame, cornerRadius: 24)
        island.fillColor = index.isMultiple(of: 2)
            ? SKColor(red: 0.04, green: 0.66, blue: 0.67, alpha: 1)
            : SKColor(red: 0.95, green: 0.31, blue: 0.17, alpha: 1)
        island.strokeColor = SKColor.white.withAlphaComponent(0.62)
        island.lineWidth = 2
        if word == "." {
            island.fillColor = SKColor(red: 0.80, green: 0.48, blue: 0.04, alpha: 1)
        }
        container.addChild(island)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = word
        label.fontSize = min(30, max(18, 280 / CGFloat(max(word.count, 1))))
        if word == "." { label.fontSize = 44 }
        if label.frame.width > frame.width - 24 {
            label.fontSize *= (frame.width - 24) / label.frame.width
        }
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: frame.midX, y: frame.midY - 1)
        label.fontColor = .white
        label.zPosition = 1
        container.addChild(label)
        return container
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isRescuing, !simulation.isDead, !simulation.platforms.isEmpty else { return }
        guard lastUpdateTime > 0 else {
            lastUpdateTime = currentTime
            return
        }

        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        // Do not count a background/resume gap as play time or a physics step.
        guard delta > 0, delta < 0.25 else { return }
        let landing = simulation.advance(delta: delta, steeringTargetX: steeringTargetX)
        showCollectedCoins()
        player.position = simulation.position
        cameraNode.position.x = size.width / 2
        cameraNode.position.y = max(cameraNode.position.y, player.position.y + size.height * 0.08)
        updateScenery()
        if let landing { reportProgress(at: landing) }

        if simulation.detectFall(below: cameraNode.position.y - size.height / 2 - player.size.height) {
            steeringTargetX = nil
            showSkeletonTransformation()
        }
    }

    func resetFrameClock() { lastUpdateTime = 0 }

    private func updateScenery() {
        scenery.update(cameraClimb: cameraNode.position.y - size.height / 2,
                       activeSeconds: simulation.activeSeconds)
    }

    private func showSkeletonTransformation() {
        player.removeAllActions()
        player.position.y = cameraNode.position.y - size.height / 2 + 100
        player.texture = SKTexture(imageNamed: "WordLeapSkeleton")
        let rise = SKAction.move(to: CGPoint(x: cameraNode.position.x,
            y: cameraNode.position.y + 110), duration: reduceMotion ? 0 : 0.7)
        rise.timingMode = .easeOut
        player.run(.group([rise, .scale(to: 1.6, duration: reduceMotion ? 0 : 0.7)]))
        let collectedDoubloons = simulation.collectedCoins.count
        let activeSeconds = simulation.activeSeconds
        run(.sequence([.wait(forDuration: reduceMotion ? 0 : 0.8), .run { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.reportDeath(collectedDoubloons, activeSeconds) }
        }]), withKey: "deathReveal")
    }

    func retryFromCheckpoint() {
        removeAction(forKey: "deathReveal")
        player.removeAllActions()
        player.texture = SKTexture(imageNamed: "WordLeapHero")
        player.setScale(1)
        player.alpha = 1
        player.zRotation = 0
        layoutWorld()
        lastUpdateTime = 0
    }

    private func returnToCheckpoint() {
        simulation.resetToCheckpoint()
        player.position = simulation.position
        steeringTargetX = nil
        cameraNode.position = CGPoint(
            x: size.width / 2,
            y: max(size.height / 2, player.position.y + size.height * 0.08)
        )
    }

    private func reportProgress(at index: Int) {
        let platform = simulation.platforms[index]
        playLandingPulse(at: platform.frame)
        Task { @MainActor in reportLanding(platform.index, platform.word) }
        if index == simulation.platforms.count - 1 { beamUpToSafety() }
    }

    private func beamUpToSafety() {
        guard !isRescuing else { return }
        isRescuing = true
        steeringTargetX = nil
        let top = cameraNode.position.y + size.height / 2 + player.size.height
        let beam = SKShapeNode(rect: CGRect(x: player.position.x - 52, y: player.position.y - 48,
            width: 104, height: max(1, top - player.position.y + 48)), cornerRadius: 40)
        beam.fillColor = SKColor.cyan.withAlphaComponent(0.28)
        beam.strokeColor = SKColor.white.withAlphaComponent(0.55)
        beam.glowWidth = 12
        beam.zPosition = 15
        beam.alpha = 0
        addChild(beam)
        beam.run(.sequence([.fadeIn(withDuration: 0.2), .wait(forDuration: reduceMotion ? 0.2 : 1.5),
                           .fadeOut(withDuration: 0.3), .removeFromParent()]))
        burstConfetti()
        let lift = SKAction.moveTo(y: top, duration: reduceMotion ? 0.2 : 1.7)
        lift.timingMode = .easeIn
        player.run(.sequence([.wait(forDuration: 0.15), .group([
            lift, .scale(to: 0.35, duration: reduceMotion ? 0.2 : 1.7),
            .rotate(toAngle: 0, duration: 0.2)
        ]), .fadeOut(withDuration: 0.15)]))
        // The central book appears during the final part of the rescue.
        run(.sequence([.wait(forDuration: reduceMotion ? 0.4 : 1.1), .run { [weak self] in
            guard let self else { return }
            let collectedDoubloons = self.simulation.collectedCoins.count
            let activeSeconds = self.simulation.activeSeconds
            Task { @MainActor in self.reportRescue(collectedDoubloons, activeSeconds) }
        }]))
    }

    private func burstConfetti() {
        guard !reduceMotion else { return }
        let colours: [SKColor] = [.systemYellow, .systemPink, .cyan, .white, .systemOrange]
        for index in 0..<90 {
            let particle = SKSpriteNode(color: colours[index % colours.count], size: CGSize(width: 6, height: 10))
            particle.zPosition = 50
            cameraNode.addChild(particle)
            let angle = CGFloat(index) * 2.39996
            let speed = CGFloat(110 + (index * 47) % 200)
            particle.run(.sequence([.group([
                .customAction(withDuration: 3) { node, elapsed in
                    node.position = CGPoint(x: cos(angle) * speed * elapsed,
                        y: sin(angle) * speed * elapsed - 140 * elapsed * elapsed)
                    node.zRotation = elapsed * CGFloat(index % 7 - 3)
                },
                .sequence([.wait(forDuration: 1.8), .fadeOut(withDuration: 1.2)])
            ]), .removeFromParent()]))
        }
    }

    private func playLandingPulse(at frame: CGRect) {
        let glow = SKShapeNode(ellipseIn: frame.insetBy(dx: -12, dy: -12))
        glow.fillColor = SKColor.white.withAlphaComponent(0.24)
        glow.strokeColor = .clear
        glow.zPosition = -1
        addChild(glow)
        glow.run(.sequence([.scale(to: 1.25, duration: 0.18), .fadeOut(withDuration: 0.20), .removeFromParent()]))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isRescuing, !simulation.isDead else { return }
        guard let touch = touches.first else { return }
        steeringTargetX = touch.location(in: self).x
        player.xScale = touch.location(in: self).x < player.position.x ? -1 : 1
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isRescuing, !simulation.isDead else { return }
        if let index = simulation.launch() { reportProgress(at: index) }
        touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        steeringTargetX = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}
