import Testing
@testable import CuentivaWordLeap

@MainActor
struct AppModelTests {
    @Test func launchStartsLibraryLoadingOnlyOnce() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let appModel = AppModel(
            libraryFeature: fixture.library,
            wordLeapFeature: fixture.game,
            settingsFeature: SettingsFeature()
        )

        appModel.applicationDidFinishLaunching()
        appModel.applicationDidFinishLaunching()
        await fixture.library.load().value

        #expect(fixture.library.isReady)
        #expect(fixture.library.books.count == 3)
    }
}
