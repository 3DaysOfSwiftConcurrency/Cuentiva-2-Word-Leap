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
    var worldText: Color { WorldPalette.primaryInk }
    var worldSecondaryText: Color { WorldPalette.secondaryInk }
    var worldShadow: Color { WorldPalette.deepShadow }
    var worldAccent: Color {
        switch selectedTheme {
        case .system, .storybook: WorldPalette.goldAccent
        case .sunrise: WorldPalette.coralAccent
        case .forest: WorldPalette.leafAccent
        case .ocean: WorldPalette.oceanAccent
        case .twilight: WorldPalette.lavenderAccent
        case .midnight: WorldPalette.moonlightAccent
        }
    }
    var worldPanel: Color {
        switch selectedTheme {
        case .system: WorldPalette.systemPanel
        case .storybook: WorldPalette.storybookPanel
        case .sunrise: WorldPalette.sunrisePanel
        case .forest: WorldPalette.forestPanel
        case .ocean: WorldPalette.oceanPanel
        case .twilight: WorldPalette.twilightPanel
        case .midnight: WorldPalette.midnightPanel
        }
    }
}

private enum WorldPalette {
    static let primaryInk = Color(red: 1, green: 0.96, blue: 0.86)
    static let secondaryInk = Color(red: 0.83, green: 0.85, blue: 0.86)
    static let deepShadow = Color(red: 0.025, green: 0.055, blue: 0.10)

    static let goldAccent = Color(red: 1, green: 0.78, blue: 0.40)
    static let coralAccent = Color(red: 1, green: 0.70, blue: 0.48)
    static let leafAccent = Color(red: 0.64, green: 0.89, blue: 0.60)
    static let oceanAccent = Color(red: 0.49, green: 0.86, blue: 0.94)
    static let lavenderAccent = Color(red: 0.83, green: 0.72, blue: 1)
    static let moonlightAccent = Color(red: 0.66, green: 0.81, blue: 1)

    static let systemPanel = Color(red: 0.035, green: 0.09, blue: 0.15).opacity(0.90)
    static let storybookPanel = Color(red: 0.19, green: 0.12, blue: 0.08).opacity(0.92)
    static let sunrisePanel = Color(red: 0.24, green: 0.10, blue: 0.09).opacity(0.92)
    static let forestPanel = Color(red: 0.045, green: 0.15, blue: 0.12).opacity(0.92)
    static let oceanPanel = Color(red: 0.035, green: 0.13, blue: 0.21).opacity(0.92)
    static let twilightPanel = Color(red: 0.15, green: 0.08, blue: 0.24).opacity(0.92)
    static let midnightPanel = Color(red: 0.025, green: 0.045, blue: 0.10).opacity(0.94)
}
