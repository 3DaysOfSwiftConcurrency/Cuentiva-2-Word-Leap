import Testing
@testable import CuentivaWordLeap

@MainActor
struct SettingsFeatureTests {
    @Test func exposesTheProductsAttributionAndArchitecture() {
        let feature = SettingsFeature()

        #expect(feature.contentAttribution == "Open Source Cuentiva Spanish Book Collection")
        #expect(feature.architecture == "Cooperative Feature Architecture")
    }
}
