import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct SettingsFeatureTests {
    @Test func restoresAndPersistsTheSelectedThemeWithASafeObsoleteFallback() throws {
        let suiteName = "SettingsFeatureTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(WordLeapTheme.forest.rawValue, forKey: "selectedWordLeapTheme")
        let appInformation = AppInformation(name: "Test App", version: "1.0", build: "1")

        let settingsFeature = SettingsFeature(defaults: defaults, appInformation: appInformation)
        #expect(settingsFeature.selectedTheme == .forest)
        #expect(settingsFeature.appInformation == appInformation)

        settingsFeature.selectTheme(.ocean)
        #expect(SettingsFeature(defaults: defaults, appInformation: appInformation).selectedTheme == .ocean)

        defaults.set("retired-theme", forKey: "selectedWordLeapTheme")
        #expect(SettingsFeature(defaults: defaults, appInformation: appInformation).selectedTheme == .system)
    }
}
