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
            settingsFeature: SettingsFeature(
                defaults: .standard,
                appInformation: AppInformation(name: "Test App", version: "1.0", build: "1")
            )
        )

        async let firstLaunch: Void = appModel.applicationDidFinishLaunching()
        async let repeatedLaunch: Void = appModel.applicationDidFinishLaunching()
        _ = await (firstLaunch, repeatedLaunch)

        #expect(fixture.libraryFeature.isReady)
        #expect(fixture.libraryFeature.books.count == 3)
    }
}
