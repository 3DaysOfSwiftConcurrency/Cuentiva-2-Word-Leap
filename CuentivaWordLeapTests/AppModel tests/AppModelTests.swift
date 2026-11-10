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

        let firstLaunch = try #require(appModel.applicationDidFinishLaunching())
        #expect(appModel.applicationDidFinishLaunching() == nil)
        await firstLaunch.value

        #expect(fixture.library.isReady)
        #expect(fixture.library.books.count == 3)
    }
}
