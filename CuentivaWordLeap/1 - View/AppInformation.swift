import Foundation

/// Immutable app identity prepared from the bundle for presentation.
struct AppInformation: Equatable, Sendable {
    let version: String
    let build: String

    init(version: String, build: String) {
        self.version = version
        self.build = build
    }

    init(bundle: Bundle) {
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static let current = AppInformation(bundle: .main)

    var versionDescription: String {
        "Version \(version) (\(build))"
    }
}
