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

    /// Joins the shared launch refresh without gating construction of the interface.
    func applicationDidFinishLaunching() async {
        guard !hasLaunched else { return }
        hasLaunched = true
        await libraryFeature.load().value
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
        let settingsFeature = SettingsFeature(
            defaults: .standard,
            appInformation: AppInformation(bundle: .main)
        )
        return AppModel(
            libraryFeature: libraryFeature,
            wordLeapFeature: wordLeapFeature,
            settingsFeature: settingsFeature
        )
    }
}
