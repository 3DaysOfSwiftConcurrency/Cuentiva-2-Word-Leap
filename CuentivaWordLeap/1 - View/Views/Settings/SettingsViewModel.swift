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

    var contentAttribution: String { settingsFeature.contentAttribution }
    var architecture: String { settingsFeature.architecture }
    var version: String { appInformation.versionDescription }
}
