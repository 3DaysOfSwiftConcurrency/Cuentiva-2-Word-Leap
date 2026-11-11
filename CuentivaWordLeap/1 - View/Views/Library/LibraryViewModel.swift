import Foundation
import Observation

@MainActor @Observable
final class LibraryViewModel {
    private let libraryFeature: LibraryFeature
    var selectedBook: StoryBook?

    init(libraryFeature: LibraryFeature = AppModel.shared.libraryFeature) {
        self.libraryFeature = libraryFeature
    }

    var books: [StoryBook] { libraryFeature.books }
    var castles: [AdventureCastlePresentation] {
        libraryFeature.castles.map(AdventureCastlePresentation.init)
    }
    var conqueredCount: Int { libraryFeature.conqueredCastleCount }
    var doubloonBalance: Int { libraryFeature.doubloonBalance }
    var doubloonBalanceText: String { "\(doubloonBalance)" }
    var doubloonAccessibilityLabel: String {
        doubloonBalance == 1
            ? String(localized: "\(doubloonBalance) doubloon")
            : String(localized: "\(doubloonBalance) doubloons")
    }
    var castleCountText: String {
        books.count == 1
            ? String(localized: "\(books.count) castle")
            : String(localized: "\(books.count) castles")
    }
    var conqueredCountText: String { String(localized: "\(conqueredCount) conquered") }
    var errorMessage: String? {
        switch libraryFeature.requestFailure {
        case .bundledLibrary:
            String(localized: "The Cuentiva book collection could not be opened.")
        case .remoteRefresh:
            String(localized: "GitHub could not refresh the collection. Your bundled books are still ready to play.")
        case nil:
            nil
        }
    }
    var isLoading: Bool { libraryFeature.isLoading }
    var isReady: Bool { libraryFeature.isReady }

    func select(_ book: StoryBook) {
        guard libraryFeature.canPlay(book) else { return }
        selectedBook = book
    }

    func load() -> Task<Void, Never> { libraryFeature.load() }
    func refresh() -> Task<Void, Never> { libraryFeature.refresh() }
}

struct AdventureCastlePresentation: Identifiable {
    let book: StoryBook
    let number: Int
    let isCompleted: Bool
    let isUnlocked: Bool
    let numberText: String
    let heading: String
    let characterAssetName: String
    let statusText: String
    let statusSymbol: String
    let actionSymbol: String
    let accessibilityLabel: String
    let accessibilityHint: String

    var id: String { book.id }

    init(castle: AdventureCastle) {
        book = castle.book
        number = castle.number
        isCompleted = castle.isCompleted
        isUnlocked = castle.isUnlocked
        numberText = "\(castle.number)"
        heading = String(localized: "CASTLE \(castle.number)")
        characterAssetName = castle.book.wordLeapCharacter?.spriteAssetName ?? "WordLeapMora"

        if !castle.isUnlocked {
            statusText = String(localized: "Complete Castle \(castle.number - 1)")
            statusSymbol = "lock.fill"
            actionSymbol = "lock.fill"
            accessibilityLabel = String(localized: "Castle \(castle.number), \(castle.book.title), locked")
            accessibilityHint = String(localized: "Complete Castle \(castle.number - 1) to unlock")
        } else if castle.isCompleted {
            statusText = String(localized: "Conquered · Play again")
            statusSymbol = "flag.checkered"
            actionSymbol = "flag.checkered"
            accessibilityLabel = String(localized: "Castle \(castle.number), \(castle.book.title), conquered")
            accessibilityHint = String(localized: "Opens this book's word-leap level")
        } else {
            let platformCount = castle.book.platformCount
            statusText = platformCount == 1
                ? String(localized: "\(platformCount) word platform")
                : String(localized: "\(platformCount) word platforms")
            statusSymbol = "sparkles"
            actionSymbol = "play.fill"
            accessibilityLabel = String(localized: "Castle \(castle.number), \(castle.book.title), ready to play")
            accessibilityHint = String(localized: "Opens this book's word-leap level")
        }
    }
}
