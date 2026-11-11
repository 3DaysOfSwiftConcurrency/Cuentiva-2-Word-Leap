import Foundation
import Testing
@testable import CuentivaWordLeap
#if canImport(UIKit)
import UIKit
#endif

struct GameCharacterTests {
    @Test func castHasNineDistinctCompleteProfiles() {
        let cast = GameCharacter.cuentivaCast
        #expect(Set(cast.map(\.name)) == Set([
            "Pipa", "Brasa", "Musgo", "Zumi", "Luma", "Nube", "Tilo", "Mora", "Faro"
        ]))
        #expect(cast.count == 9)
        #expect(Set(cast.map(\.id)).count == 9)
        #expect(Set(cast.map(\.sourceAuthorID)).count == 9)
        #expect(Set(cast.map(\.spriteAssetName)).count == 9)
        #expect(Set(cast.map(\.portraitAssetName)).count == 9)
        #expect(cast.allSatisfy { !$0.biography.isEmpty && !$0.species.isEmpty })
        #expect(cast.map(\.id) == ["pipa", "brasa", "musgo", "zumi", "luma", "nube", "tilo", "mora", "faro"])
    }

    @Test(arguments: GameCharacter.cuentivaCast)
    func booksResolveTheirStorytellerProfile(character: GameCharacter) {
        let book = StoryBook(id: "fixture", storyteller: character.name,
            title: "Un cuento", englishTitle: "A story", spanishPassages: [])
        #expect(book.wordLeapCharacter == character)
        #expect(book.wordLeapPortraitAssetName == character.portraitAssetName)
    }

    @Test func unknownStorytellerDoesNotImpersonateACollectible() {
        let book = StoryBook(id: "unknown", storyteller: "New storyteller",
            title: "Un cuento", englishTitle: "A story", spanishPassages: [])
        #expect(book.wordLeapCharacter == nil)
        // Preserve the existing visual fallback without inventing a character identity.
        #expect(book.wordLeapPortraitAssetName == "StorytellerMora")
        #expect(GameCharacter.storyteller(named: "") == nil)
    }

    @MainActor @Test func featureExposesProfilesWithoutStartingAnAdventure() throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let wordLeapFeature = fixture.wordLeapFeature
        #expect(wordLeapFeature.characterProfiles == GameCharacter.cuentivaCast)
        #expect(wordLeapFeature.activeLevel == nil)
    }

    #if canImport(UIKit)
    @MainActor @Test(arguments: GameCharacter.cuentivaCast)
    func bundledArtworkLoads(character: GameCharacter) throws {
        let sprite = try #require(UIImage(named: character.spriteAssetName))
        #expect(sprite.size.width > 0 && sprite.size.height > 0)
        #expect(UIImage(named: character.portraitAssetName) != nil)
        let cgImage = try #require(sprite.cgImage)
        #expect([CGImageAlphaInfo.premultipliedFirst, .premultipliedLast, .first, .last]
            .contains(cgImage.alphaInfo))
    }
    #endif
}
