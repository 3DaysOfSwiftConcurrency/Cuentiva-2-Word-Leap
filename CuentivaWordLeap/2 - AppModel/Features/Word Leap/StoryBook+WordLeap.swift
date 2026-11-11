/// Word Leap's game-specific projection of Library-owned story data.
/// Keeping it here makes the dependency one-way: Word Leap may use StoryBook,
/// while the Library feature remains independent of game characters and scenery.
extension StoryBook {
    var wordLeapCharacter: GameCharacter? {
        GameCharacter.storyteller(named: storyteller)
    }

    var wordLeapPortraitAssetName: String {
        wordLeapCharacter?.portraitAssetName ?? "StorytellerMora"
    }

    var wordLeapEnvironment: BookEnvironment {
        BookEnvironment.forBook(id: id)
    }

    var wordLeapBackgroundAssetName: String {
        wordLeapEnvironment.backdropAssetName
    }
}
