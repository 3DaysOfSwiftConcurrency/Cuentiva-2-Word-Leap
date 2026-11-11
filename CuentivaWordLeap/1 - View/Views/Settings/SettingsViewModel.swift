import Foundation
import Observation

@MainActor @Observable
final class SettingsViewModel {
    private let settingsFeature: SettingsFeature
    private let appInformation: AppInformation

    init(
        settingsFeature: SettingsFeature = AppModel.shared.settingsFeature,
        appInformation: AppInformation = .current
    ) {
        self.settingsFeature = settingsFeature
        self.appInformation = appInformation
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
    var version: String { appInformation.versionDescription }
}
