import Foundation

@MainActor
final class AppModel {
    static let shared = live()
    let libraryFeature: LibraryFeature
    let wordLeapFeature: WordLeapFeature
    let settingsFeature: SettingsFeature
    private var hasLaunched: Bool

    init(libraryFeature: LibraryFeature, wordLeapFeature: WordLeapFeature, settingsFeature: SettingsFeature) {
        self.libraryFeature = libraryFeature
        self.wordLeapFeature = wordLeapFeature
        self.settingsFeature = settingsFeature
        hasLaunched = false
    }

    /// Signals Feature-owned startup work synchronously without waiting for I/O.
    func applicationDidFinishLaunching() {
        guard !hasLaunched else { return }
        hasLaunched = true
        libraryFeature.load()
    }

    static func live() -> AppModel {
        let networkingManager = NetworkingManager()
        let bookRepository = CuentivaBookRepository(networkingManager: networkingManager)
        let levelPlanBuilder = LevelPlanBuilder(vocabularyURL: Bundle.main.url(forResource: "verbs", withExtension: "json"))
        let levelProgressStore = LevelProgressStore()
        let libraryFeature = LibraryFeature(
            bookRepository: bookRepository,
            levelProgressStore: levelProgressStore
        )
        let wordLeapFeature = WordLeapFeature(
            levelPlanBuilder: levelPlanBuilder,
            libraryFeature: libraryFeature
        )
        return AppModel(
            libraryFeature: libraryFeature,
            wordLeapFeature: wordLeapFeature,
            settingsFeature: SettingsFeature()
        )
    }
}
