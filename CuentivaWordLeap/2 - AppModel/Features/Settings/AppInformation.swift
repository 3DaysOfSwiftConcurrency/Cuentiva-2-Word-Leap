import Foundation

/// Immutable application identity exposed by SettingsFeature for presentation.
struct AppInformation: Equatable, Sendable {
    let name: String
    let version: String
    let build: String

    init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }

    init(bundle: Bundle) {
        name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "App"
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
