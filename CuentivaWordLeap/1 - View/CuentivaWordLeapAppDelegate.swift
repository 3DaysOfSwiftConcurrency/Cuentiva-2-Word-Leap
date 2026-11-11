import UIKit

@MainActor
final class CuentivaWordLeapAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppModel.shared.applicationDidFinishLaunching()
        return true
    }
}
