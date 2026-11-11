import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct ThemeManagerTests {
    @Test func selectionRoutesThroughTheSettingsFeature() throws {
        let suiteName = "ThemeManagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settingsFeature = SettingsFeature(
            defaults: defaults,
            appInformation: AppInformation(name: "Test App", version: "1.0", build: "1")
        )
        let themeManager = ThemeManager(settingsFeature: settingsFeature)

        themeManager.selectedTheme = .twilight

        #expect(settingsFeature.selectedTheme == .twilight)
        #expect(defaults.string(forKey: "selectedWordLeapTheme") == WordLeapTheme.twilight.rawValue)
    }
}
