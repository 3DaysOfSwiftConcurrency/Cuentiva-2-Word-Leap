import Observation
import SwiftUI

extension WordLeapTheme {
    var title: String { rawValue.capitalized }
}

@MainActor @Observable
final class ThemeManager {
    private let settingsFeature: SettingsFeature

    var selectedTheme: WordLeapTheme {
        get { settingsFeature.selectedTheme }
        set { settingsFeature.selectTheme(newValue) }
    }

    init(settingsFeature: SettingsFeature = AppModel.shared.settingsFeature) {
        self.settingsFeature = settingsFeature
    }

    // Illustrated screens keep light ink on dark surfaces in every colour theme.
    var worldText: Color { Color(red: 1, green: 0.96, blue: 0.86) }
    var worldSecondaryText: Color { Color(red: 0.83, green: 0.85, blue: 0.86) }
    var worldShadow: Color { Color(red: 0.025, green: 0.055, blue: 0.10) }
    var worldAccent: Color {
        switch selectedTheme {
        case .system, .storybook: Color(red: 1, green: 0.78, blue: 0.40)
        case .sunrise: Color(red: 1, green: 0.70, blue: 0.48)
        case .forest: Color(red: 0.64, green: 0.89, blue: 0.60)
        case .ocean: Color(red: 0.49, green: 0.86, blue: 0.94)
        case .twilight: Color(red: 0.83, green: 0.72, blue: 1)
        case .midnight: Color(red: 0.66, green: 0.81, blue: 1)
        }
    }
    var worldPanel: Color {
        switch selectedTheme {
        case .system: Color(red: 0.035, green: 0.09, blue: 0.15).opacity(0.90)
        case .storybook: Color(red: 0.19, green: 0.12, blue: 0.08).opacity(0.92)
        case .sunrise: Color(red: 0.24, green: 0.10, blue: 0.09).opacity(0.92)
        case .forest: Color(red: 0.045, green: 0.15, blue: 0.12).opacity(0.92)
        case .ocean: Color(red: 0.035, green: 0.13, blue: 0.21).opacity(0.92)
        case .twilight: Color(red: 0.15, green: 0.08, blue: 0.24).opacity(0.92)
        case .midnight: Color(red: 0.025, green: 0.045, blue: 0.10).opacity(0.94)
        }
    }
}
