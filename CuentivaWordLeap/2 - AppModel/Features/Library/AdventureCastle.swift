import Foundation

/// A numbered book and its access state, owned by the library's progression policy.
struct AdventureCastle: Identifiable, Sendable {
    let book: StoryBook
    let number: Int
    let isCompleted: Bool
    let isUnlocked: Bool

    var id: String { book.id }
}

enum CastleAccessError: LocalizedError, Equatable {
    case libraryUnavailable
    case unknownBook
    case locked(previousCastle: Int)

    var errorDescription: String? {
        switch self {
        case .libraryUnavailable: "The adventure could not be loaded. Return to the map and try again."
        case .unknownBook: "This book is no longer on the adventure map."
        case .locked(let number): "Complete Castle \(number) to unlock this adventure."
        }
    }
}
