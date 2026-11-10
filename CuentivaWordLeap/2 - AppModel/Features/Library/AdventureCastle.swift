/// A numbered book and its access state, owned by the library's progression policy.
struct AdventureCastle: Identifiable, Sendable {
    let book: StoryBook
    let number: Int
    let isCompleted: Bool
    let isUnlocked: Bool

    var id: String { book.id }
}

enum CastleAccessError: Error, Equatable {
    case libraryUnavailable
    case unknownBook
    case locked(previousCastle: Int)
}
