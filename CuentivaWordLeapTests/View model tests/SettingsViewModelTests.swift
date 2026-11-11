import Foundation
import Testing
@testable import CuentivaWordLeap

@MainActor
struct SettingsViewModelTests {
    @Test func preparesAboutCopyAndRoutesThemeSelectionThroughTheFeature() throws {
        let suiteName = "SettingsViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settingsFeature = SettingsFeature(
            defaults: defaults,
            appInformation: AppInformation(name: "Test App", version: "2.4", build: "81")
        )
        let viewModel = SettingsViewModel(settingsFeature: settingsFeature)

        viewModel.selectedTheme = .ocean

        #expect(settingsFeature.selectedTheme == .ocean)
        #expect(viewModel.contentAttribution == "Open Source Cuentiva Spanish Book Collection")
        #expect(viewModel.architecture == "Cooperative Feature Architecture")
        #expect(viewModel.appName == "Test App")
        #expect(viewModel.version == "Version 2.4 (81)")
    }
}
