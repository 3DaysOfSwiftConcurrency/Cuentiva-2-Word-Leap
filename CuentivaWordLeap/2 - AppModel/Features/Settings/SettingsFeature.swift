import Foundation
import Observation

enum WordLeapTheme: String, CaseIterable, Identifiable {
    case system, storybook, sunrise, forest, ocean, twilight, midnight

    var id: String { rawValue }
}

@MainActor @Observable
final class SettingsFeature {
    private static let selectedThemeStorageKey = "selectedWordLeapTheme"
    private let defaults: UserDefaults
    private(set) var selectedTheme: WordLeapTheme

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTheme = defaults.string(forKey: Self.selectedThemeStorageKey)
        selectedTheme = storedTheme.flatMap(WordLeapTheme.init(rawValue:)) ?? .system
    }

    func selectTheme(_ theme: WordLeapTheme) {
        defaults.set(theme.rawValue, forKey: Self.selectedThemeStorageKey)
        selectedTheme = theme
    }
}
