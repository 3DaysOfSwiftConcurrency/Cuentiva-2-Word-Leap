import Foundation

/// Immutable app identity prepared from the bundle for presentation.
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

    static let current = AppInformation(bundle: .main)

    var versionDescription: String {
        "Version \(version) (\(build))"
    }
}
