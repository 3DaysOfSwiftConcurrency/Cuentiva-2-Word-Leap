import Testing
@testable import CuentivaWordLeap

@MainActor
struct AppModelTests {
    @Test func launchStartsLibraryLoadingOnlyOnce() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let appModel = AppModel(
            libraryFeature: fixture.libraryFeature,
            wordLeapFeature: fixture.wordLeapFeature,
            settingsFeature: SettingsFeature()
        )

        appModel.applicationDidFinishLaunching()
        appModel.applicationDidFinishLaunching()
        await fixture.libraryFeature.load().value

        #expect(fixture.libraryFeature.isReady)
        #expect(fixture.libraryFeature.books.count == 3)
    }
}
