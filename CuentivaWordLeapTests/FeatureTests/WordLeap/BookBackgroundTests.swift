import Foundation
import Testing
@testable import CuentivaWordLeap
#if canImport(UIKit)
import UIKit
#endif

struct BookBackgroundTests {
    // The released adventure order is deliberately pinned: replays and remote
    // catalogue/title edits must never reshuffle an existing book's environment.
    private static let adventure: [(id: String, environment: BookEnvironment)] = [
        ("cafe", .skyFalls),
        ("garden", .skyFalls),
        ("train", .skyFalls),
        ("sea", .skyFalls),
        ("repair", .skyFalls),
        ("repair-hour", .skyFalls),
        ("loan-notebook", .skyFalls),
        ("small-guide", .skyFalls),
        ("three-paths", .skyFalls),
        ("three-envelopes", .skyFalls),
        ("rainy-roof", .coast),
        ("patient-investor", .skyFalls),
        ("first-stitch", .coast),
        ("different-door", .skyFalls),
        ("empty-wallet", .coast),
        ("shared-table", .roots),
        ("honest-change", .skyFalls),
        ("sunday-pot", .coast),
        ("film-conversation", .roots),
        ("beans-question", .skyFalls),
        ("first-invitation", .railway),
        ("thoughtful-yes", .coast),
        ("enough-on-paper", .roots),
        ("useful-service", .skyFalls),
        ("travelling-seed", .railway),
        ("tomato-question", .puddle),
        ("garden-colours", .coast),
        ("potato-basket", .roots),
        ("two-carrots", .skyFalls),
        ("body-care", .railway),
        ("water-toast", .observatory),
        ("pause-before-plan", .puddle),
        ("ten-pages", .coast),
        ("metaphor-not-law", .roots),
        ("world-in-backpack", .skyFalls),
        ("brand-from-within", .harbour),
        ("four-years-road", .railway),
        ("calendar-of-later", .observatory),
        ("cow-two-names", .puddle),
        ("cube-among-stars", .coast),
        ("feet-on-earth", .theatre),
        ("travelling-sun", .roots),
        ("no-place-to-land", .skyFalls),
        ("wrong-suitcase", .harbour),
        ("table-for-three", .railway),
        ("last-train-scene", .orchard),
        ("verb-ser", .observatory),
        ("verb-estar", .puddle),
        ("verb-querer", .coast),
        ("nearby-bangkok", .theatre),
        ("nearby-pattaya", .storm),
        ("nearby-thailand", .letters)
    ]

    @Test func firstTenBooksStayInSkyFalls() throws {
        let books = try bundledBooks()
        #expect(books.count == 52)
        #expect(Array(books.prefix(10).map(\.wordLeapEnvironment)) == Array(repeating: .skyFalls, count: 10))
    }

    @Test func everyBookHasItsFixedAdventureEnvironment() throws {
        let books = try bundledBooks()
        #expect(books.map(\.id) == Self.adventure.map(\.id))
        #expect(books.map(\.wordLeapEnvironment) == Self.adventure.map(\.environment))
        #expect(Set(books.map(\.wordLeapEnvironment)) == Set(BookEnvironment.allCases))
        for book in books {
            #expect(book.wordLeapBackgroundAssetName == book.wordLeapEnvironment.backdropAssetName)
        }
    }

    @Test func newEnvironmentsOnlyDebutAtMilestonesAndTheFinale() throws {
        let books = try bundledBooks()
        let debuts: [Int: BookEnvironment] = [
            1: .skyFalls, 11: .coast, 16: .roots, 21: .railway,
            26: .puddle, 31: .observatory, 36: .harbour, 41: .theatre,
            46: .orchard, 51: .storm, 52: .letters
        ]
        var seen: Set<BookEnvironment> = []
        for (index, book) in books.enumerated() {
            if let debut = debuts[index + 1] {
                #expect(book.wordLeapEnvironment == debut)
                #expect(!seen.contains(debut))
            } else {
                #expect(seen.contains(book.wordLeapEnvironment), "No early reveal at book \(index + 1)")
            }
            seen.insert(book.wordLeapEnvironment)
        }
    }

    @Test func environmentsAlternateAfterTheIntroduction() throws {
        let books = try bundledBooks()
        for (previous, next) in zip(books.dropFirst(9), books.dropFirst(10)) {
            #expect(previous.wordLeapEnvironment != next.wordLeapEnvironment)
        }
        #expect(Array(books.dropFirst(10).prefix(5).map(\.wordLeapEnvironment)) ==
            [.coast, .skyFalls, .coast, .skyFalls, .coast])
        #expect(Array(books.dropFirst(15).prefix(5).map(\.wordLeapEnvironment)) ==
            [.roots, .skyFalls, .coast, .roots, .skyFalls])
    }

    @Test func retriesAndChangedTitlesOrOrderKeepTheirEnvironment() throws {
        let books = try bundledBooks()
        for book in books.reversed() {
            let renamed = StoryBook(id: book.id, storyteller: "Pipa", title: "A changed title",
                englishTitle: "", spanishPassages: [])
            for _ in 0..<3 {
                #expect(renamed.wordLeapEnvironment == book.wordLeapEnvironment)
                #expect(renamed.wordLeapBackgroundAssetName == book.wordLeapBackgroundAssetName)
            }
        }
    }

    @Test func newBooksReceiveTheReusableSkyFallsPack() {
        let book = StoryBook(id: "new-from-github", storyteller: "Pipa", title: "",
            englishTitle: "", spanishPassages: [])
        #expect(book.wordLeapEnvironment == .skyFalls)
        #expect(book.wordLeapBackgroundAssetName == "SkyFallsBackdrop")
        #expect(!ParallaxSceneryRecipe(environment: book.wordLeapEnvironment).layers.isEmpty)
    }

    #if canImport(UIKit)
    @MainActor @Test func allBundledBackgroundsLoadAsPortraitImages() throws {
        for name in BookEnvironment.allCases.map(\.backdropAssetName) {
            let image = try #require(UIImage(named: name))
            #expect(image.size.width > 0)
            #expect(image.size.height > image.size.width)
        }
    }

    @MainActor @Test func sceneryCutoutsHaveTransparency() throws {
        let names = BookEnvironment.allCases.flatMap {
            ParallaxSceneryRecipe(environment: $0).layers.map(\.assetName)
        }
        for name in names {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect([CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast]
                .contains(image.alphaInfo))
            // An alpha channel alone can still contain a fully opaque rectangle.
            var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
            let transparentPixels = try pixels.withUnsafeMutableBytes { bytes in
                let context = try #require(CGContext(data: bytes.baseAddress, width: 64, height: 64,
                    bitsPerComponent: 8, bytesPerRow: 64 * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
                return stride(from: 3, to: bytes.count, by: 4).filter { bytes[$0] == 0 }.count
            }
            #expect(transparentPixels > 100, "Scenery must have a genuinely transparent surround: \(name)")
        }
    }
    #endif

    private func bundledBooks() throws -> [StoryBook] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        let url = try #require(bundle.url(forResource: "stories", withExtension: "txt"))
        return try CuentivaBookRepository.decode(Data(contentsOf: url))
    }
}
