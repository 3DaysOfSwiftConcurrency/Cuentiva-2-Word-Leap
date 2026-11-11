import SwiftUI

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image("WordLeapTilo")
                            .resizable().scaledToFit().frame(height: 140)
                            .shadow(color: themeManager.worldAccent.opacity(0.3), radius: 18)
                            .accessibilityHidden(true)
                        Text("A moment at camp")
                            .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        Text("Make this little world your own.")
                            .font(.subheadline).foregroundStyle(themeManager.worldSecondaryText)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("APPEARANCE")
                            .font(.caption.weight(.heavy)).tracking(2)
                            .foregroundStyle(themeManager.worldAccent)
                        Picker("Colour theme", selection: $viewModel.selectedTheme) {
                            ForEach(WordLeapTheme.allCases) { theme in
                                Text(theme.title).tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(themeManager.worldAccent)
                    }
                    .padding(22)
                    .worldPanel()

                    VStack(alignment: .leading, spacing: 18) {
                        Text("ABOUT THIS WORLD")
                            .font(.caption.weight(.heavy)).tracking(2)
                            .foregroundStyle(themeManager.worldAccent)
                        LabeledContent("App") {
                            Text(viewModel.appName)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(themeManager.worldAccent)
                        }
                        Divider().overlay(themeManager.worldAccent.opacity(0.3))
                        LabeledContent("Learning content") {
                            Text(viewModel.contentAttribution)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(themeManager.worldSecondaryText)
                        }
                        Divider().overlay(themeManager.worldAccent.opacity(0.3))
                        LabeledContent("Architecture") {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(viewModel.architecture)
                                Text("Built with SwiftUI and SpriteKit.").font(.caption)
                            }
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(themeManager.worldSecondaryText)
                        }
                        Divider().overlay(themeManager.worldAccent.opacity(0.3))
                        LabeledContent("Version") {
                            Text(viewModel.version).foregroundStyle(themeManager.worldSecondaryText)
                        }
                    }
                    .padding(22)
                    .worldPanel()
                }
                .frame(maxWidth: 580)
                .padding(24)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            .foregroundStyle(themeManager.worldText)
            .background { WorldBackdrop(shade: 0.27) }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
