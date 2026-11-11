import Foundation
import CoreGraphics

struct WordPlatform {
    let index: Int
    let word: String
    let frame: CGRect
}

/// Shared by the live scene and regression tests, in scene points and seconds.
struct WordLeapSimulation {
    static let gravity: CGFloat = 1_520
    static let jumpSpeed: CGFloat = 720
    static let footOffset: CGFloat = 32
    static let maximumHorizontalSpeed: CGFloat = 340
    static let maximumJumpHeight = jumpSpeed * jumpSpeed / (2 * gravity)
    // Leave 40% of the jump height as headroom, rather than requiring a perfect jump.
    static let platformRise = floor(maximumJumpHeight * 0.60)
    static let steeringGracePeriod: CGFloat = 0.18
    static let landingTime = (jumpSpeed + sqrt(jumpSpeed * jumpSpeed - 2 * gravity * platformRise)) / gravity
    static let maximumCentreStep = min(96, maximumHorizontalSpeed * (landingTime - steeringGracePeriod) * 0.5)

    let viewport: CGSize
    let platforms: [WordPlatform]
    let coins: [Int: CGPoint]
    private(set) var collectedCoins: Set<Int>
    private(set) var position: CGPoint = .zero
    private(set) var verticalVelocity: CGFloat = 0
    private(set) var furthestPlatformIndex: Int = -1
    private(set) var isWaitingForLaunch = true
    private(set) var isDead = false
    private(set) var activeSeconds: TimeInterval

    init(words: [String], viewport: CGSize, checkpointIndex: Int = -1, collectedCoins: Set<Int> = [],
         activeSeconds: TimeInterval = 0) {
        self.viewport = viewport
        self.activeSeconds = activeSeconds.isFinite ? max(0, activeSeconds) : 0
        var generated: [WordPlatform] = []
        var previousX = viewport.width / 2
        for (index, word) in words.enumerated() {
            let desiredWidth: CGFloat = index == 0 ? 240 : max(112, min(194, CGFloat(word.count * 14 + 48)))
            let width = min(max(1, viewport.width - 36), desiredWidth)
            let sidePadding = width / 2 + 18
            let span = min(200, max(viewport.width - sidePadding * 2, 0))
            let pattern = CGFloat((index * 71 + 43) % 100) / 100
            let desiredX = index == 0 ? viewport.width / 2 : viewport.width / 2 + span * (pattern - 0.5)
            let x = min(previousX + Self.maximumCentreStep, max(previousX - Self.maximumCentreStep, desiredX))
            let boundedX = min(viewport.width - sidePadding, max(sidePadding, x))
            let y = max(156, viewport.height * 0.22) + CGFloat(index) * Self.platformRise
            generated.append(WordPlatform(index: index, word: word,
                frame: CGRect(x: boundedX - width / 2, y: y - 26, width: width, height: 52)))
            previousX = boundedX
        }
        platforms = generated
        let coinCount = min(30, generated.count)
        var placements: [Int: CGPoint] = [:]
        for coin in 0..<coinCount {
            let index = coinCount == 1 ? 0 : coin * (generated.count - 1) / (coinCount - 1)
            let platform = generated[index]
            placements[index] = CGPoint(x: platform.frame.midX, y: platform.frame.maxY + 65)
        }
        coins = placements
        self.collectedCoins = collectedCoins.intersection(placements.keys)
        furthestPlatformIndex = max(-1, min(checkpointIndex, generated.count - 1))
        resetToCheckpoint()
    }

    mutating func resetToCheckpoint() {
        guard !platforms.isEmpty else { return }
        let platform = platforms[max(0, furthestPlatformIndex)]
        position = CGPoint(x: platform.frame.midX, y: platform.frame.maxY + Self.footOffset)
        verticalVelocity = 0
        isWaitingForLaunch = true
        isDead = false
    }

    /// Returns true only for the transition into death, so one fall shows one dialog.
    mutating func detectFall(below boundary: CGFloat) -> Bool {
        guard !isDead, !isWaitingForLaunch, position.y < boundary else { return false }
        isDead = true
        verticalVelocity = 0
        return true
    }

    /// Spawn is supported and stationary until the player explicitly begins.
    mutating func launch() -> Int? {
        guard !isDead, isWaitingForLaunch, !platforms.isEmpty,
              furthestPlatformIndex < platforms.count - 1 else { return nil }
        isWaitingForLaunch = false
        verticalVelocity = Self.jumpSpeed
        if furthestPlatformIndex == -1 {
            furthestPlatformIndex = 0
            if platforms.count == 1 {
                verticalVelocity = 0
                isWaitingForLaunch = true
            }
            return 0
        }
        return nil
    }

    mutating func advance(delta: TimeInterval, steeringTargetX: CGFloat?) -> Int? {
        guard !isDead, !isWaitingForLaunch, delta > 0, delta.isFinite else { return nil }
        activeSeconds += delta
        let dt = CGFloat(min(delta, 1.0 / 30.0))
        let previous = position
        let horizontalVelocity = steeringTargetX.map {
            min(Self.maximumHorizontalSpeed, max(-Self.maximumHorizontalSpeed, ($0 - position.x) * 7))
        } ?? 0
        position.x = min(max(position.x + horizontalVelocity * dt, 38), viewport.width - 38)
        position.y += verticalVelocity * dt - 0.5 * Self.gravity * dt * dt
        verticalVelocity -= Self.gravity * dt
        collectCoins(from: previous, to: position)
        guard verticalVelocity < 0 else { return nil }

        for platform in platforms.reversed() where platform.index <= furthestPlatformIndex + 1 {
            let top = platform.frame.maxY
            let previousFoot = previous.y - Self.footOffset
            let currentFoot = position.y - Self.footOffset
            guard previousFoot >= top, currentFoot <= top else { continue }
            let fraction = (previousFoot - top) / max(previousFoot - currentFoot, .ulpOfOne)
            let crossingX = previous.x + (position.x - previous.x) * fraction
            // Top-edge contact is inclusive. CGRect.contains excludes maxY.
            guard crossingX >= platform.frame.minX - 14,
                  crossingX <= platform.frame.maxX + 14 else { continue }
            position.y = top + Self.footOffset
            verticalVelocity = Self.jumpSpeed
            if platform.index > furthestPlatformIndex {
                furthestPlatformIndex = platform.index
                if platform.index == platforms.count - 1 {
                    verticalVelocity = 0
                    isWaitingForLaunch = true
                }
                return platform.index
            }
            return nil
        }
        return nil
    }

    private mutating func collectCoins(from start: CGPoint, to end: CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        for (index, coin) in coins where !collectedCoins.contains(index) {
            let fraction = lengthSquared > 0
                ? min(1, max(0, ((coin.x - start.x) * dx + (coin.y - start.y) * dy) / lengthSquared)) : 0
            let distanceX = coin.x - (start.x + fraction * dx)
            let distanceY = coin.y - (start.y + fraction * dy)
            if distanceX * distanceX + distanceY * distanceY <= 42 * 42 {
                collectedCoins.insert(index)
            }
        }
    }
}
