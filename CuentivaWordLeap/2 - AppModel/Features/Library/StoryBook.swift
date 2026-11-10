import Foundation

struct StoryBook: Identifiable, Hashable, Sendable {
    let id: String
    let storyteller: String
    let title: String
    let englishTitle: String
    let spanishPassages: [String]
    let englishPassages: [String]
    let cover: StoryBookCover

    init(
        id: String,
        storyteller: String,
        title: String,
        englishTitle: String,
        spanishPassages: [String],
        englishPassages: [String] = [],
        cover: StoryBookCover = StoryBookCover()
    ) {
        self.id = id
        self.storyteller = storyteller
        self.title = title
        self.englishTitle = englishTitle
        self.spanishPassages = spanishPassages
        self.englishPassages = englishPassages
        self.cover = cover
    }

    var platformCount: Int { spanishPassages.flatMap(SpanishWordTokenizer.platformTokens).count }
    var bilingualPassages: [StoryBookPassage] {
        spanishPassages.enumerated().map { passageIndex, spanish in
            let translation = englishPassages.indices.contains(passageIndex)
                ? englishPassages[passageIndex]
                : ""
            return StoryBookPassage(
                spanish: spanish,
                english: translation.isEmpty ? nil : translation
            )
        }
    }
    var characterProfile: GameCharacter? { GameCharacter.storyteller(named: storyteller) }

    var portraitAssetName: String {
        characterProfile?.portraitAssetName ?? "StorytellerMora"
    }

    var backgroundAssetName: String { environment.backdropAssetName }

    var environment: BookEnvironment { BookEnvironment.forBook(id: id) }
}

struct StoryBookPassage: Equatable, Sendable {
    let spanish: String
    let english: String?
}

struct StoryBookCover: Codable, Hashable, Sendable {
    let level: String
    let symbol: String
    let palette: Int

    init(level: String = "A1", symbol: String = "book.closed", palette: Int = 0) {
        self.level = level
        self.symbol = symbol
        self.palette = palette
    }
}

enum SpanishWordTokenizer {
    static func platformTokens(_ passage: String) -> [String] {
        var tokens: [String] = []
        var word = ""
        for character in passage {
            if character.isLetter {
                word.append(character)
            } else {
                if !word.isEmpty {
                    tokens.append(word)
                    word = ""
                }
                if character == "." { tokens.append(".") }
            }
        }
        if !word.isEmpty { tokens.append(word) }
        return tokens
    }
}
