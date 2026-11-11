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
        let settingsFeature = SettingsFeature(defaults: defaults)
        #expect(settingsFeature.selectedTheme == .forest)

        settingsFeature.selectTheme(.ocean)
        #expect(SettingsFeature(defaults: defaults).selectedTheme == .ocean)

        defaults.set("retired-theme", forKey: "selectedWordLeapTheme")
        #expect(SettingsFeature(defaults: defaults).selectedTheme == .system)
    }
}
