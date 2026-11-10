import Testing
@testable import CuentivaWordLeap

@MainActor
struct SettingsViewModelTests {
    @Test func preparesArchitectureAttributionAndInjectedVersion() {
        let viewModel = SettingsViewModel(
            settingsFeature: SettingsFeature(),
            appInformation: AppInformation(version: "2.4", build: "81")
        )

        #expect(viewModel.contentAttribution == "Open Source Cuentiva Spanish Book Collection")
        #expect(viewModel.architecture == "Cooperative Feature Architecture")
        #expect(viewModel.version == "Version 2.4 (81)")
    }
}
