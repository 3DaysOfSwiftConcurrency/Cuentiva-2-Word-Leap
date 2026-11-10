import Foundation

/// The local source of truth for completed story worlds and collected treasure.
actor LevelProgressStore {
    private let completedBookIDsKey = "completedWordLeapBookIDs"
    private let doubloonBalanceKey = "wordLeapDoubloonBalance"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func completedBookIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: completedBookIDsKey) ?? [])
    }

    func recordCompletion(of bookID: String) {
        var completed = completedBookIDs()
        completed.insert(bookID)
        defaults.set(completed.sorted(), forKey: completedBookIDsKey)
    }

    func doubloonBalance() -> Int {
        max(0, defaults.integer(forKey: doubloonBalanceKey))
    }

    /// Read and increment within one actor turn; never replace with a caller's snapshot.
    func addDoubloons(_ amount: Int) -> Int {
        let balance = doubloonBalance()
        guard amount > 0 else { return balance }
        let updated = balance + min(amount, Int.max - balance)
        defaults.set(updated, forKey: doubloonBalanceKey)
        return updated
    }
}
