import Foundation
import Observation

@MainActor @Observable
final class SettingsViewModel {
    private let settingsFeature: SettingsFeature

    init(settingsFeature: SettingsFeature = AppModel.shared.settingsFeature) {
        self.settingsFeature = settingsFeature
    }

    var selectedTheme: WordLeapTheme {
        get { settingsFeature.selectedTheme }
        set { settingsFeature.selectTheme(newValue) }
    }
    var contentAttribution: String {
        String(localized: "Open Source Cuentiva Spanish Book Collection")
    }
    var architecture: String {
        String(localized: "Cooperative Feature Architecture")
    }
    var appName: String { settingsFeature.appInformation.name }
    var version: String {
        let appInformation = settingsFeature.appInformation
        return String(localized: "Version \(appInformation.version) (\(appInformation.build))")
    }
}
