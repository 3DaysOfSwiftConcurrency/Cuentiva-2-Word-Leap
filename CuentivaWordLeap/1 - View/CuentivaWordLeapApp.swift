import SwiftUI

@main
struct CuentivaWordLeapApp: App {
    @UIApplicationDelegateAdaptor(CuentivaWordLeapAppDelegate.self) private var appDelegate
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .background {
                    WorldBackdrop(shade: 0.32, showsVignette: false)
                        .background(Color("LaunchBackground"))
                }
                .environment(themeManager)
                .tint(themeManager.worldAccent)
                // The illustrated world always uses dark chrome. Set this before
                // TabView is presented, not as a preference arriving from a tab.
                .preferredColorScheme(.dark)
        }
    }
}
