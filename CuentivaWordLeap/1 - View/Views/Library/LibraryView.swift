import SwiftUI

struct LibraryView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = LibraryViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                if viewModel.isReady {
                    storyMap.transition(.opacity)
                } else if let message = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Text(message).multilineTextAlignment(.center)
                        Button("Try again") { _ = viewModel.load() }
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.worldAccent)
                            .foregroundStyle(themeManager.worldShadow)
                    }
                    .padding(24).worldPanel().padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(themeManager.worldText)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    HStack(spacing: 7) {
                        DoubloonArtwork(size: 30)
                        Text(viewModel.doubloonBalanceText)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(themeManager.worldText)
                    }
                    .shadow(color: .black.opacity(0.85), radius: 4, y: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(viewModel.doubloonAccessibilityLabel)
                    .allowsHitTesting(false)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .opacity(viewModel.isReady ? 1 : 0)
                .accessibilityHidden(!viewModel.isReady)
            }
            // Match AdventureLaunch.storyboard's village image and uniform shade.
            .background { WorldBackdrop(shade: 0.32, showsVignette: false) }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: viewModel.isReady)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.load().value }
            .navigationDestination(item: $viewModel.selectedBook) { book in GameView(book: book) }
        }
    }

    private var storyMap: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                LibraryMapHeader(
                    castleCountText: viewModel.castleCountText,
                    conqueredCountText: viewModel.conqueredCountText
                )

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.worldAccent)
                        .padding(14)
                        .worldPanel(cornerRadius: 16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                ForEach(viewModel.castles) { castle in
                    Button { viewModel.select(castle.book) } label: {
                        StoryOutpost(castle: castle)
                    }
                    .buttonStyle(.plain)
                    .disabled(!castle.isUnlocked)
                }
            }
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.refresh().value }
    }
}

private struct LibraryMapHeader: View {
    @Environment(ThemeManager.self) private var themeManager
    let castleCountText: String
    let conqueredCountText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THE WORLD OF CUENTIVA")
                .font(.caption.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(themeManager.worldAccent)
            HStack(alignment: .center, spacing: 10) {
                Text("Every castle,\na new story.")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("WordLeapPipa")
                    .resizable().scaledToFit()
                    .frame(width: 100, height: 110)
                    .shadow(color: themeManager.worldAccent.opacity(0.3), radius: 16)
                    .accessibilityHidden(true)
            }
            Text("Complete each castle to unlock the next adventure.")
                .font(.subheadline)
                .foregroundStyle(themeManager.worldSecondaryText)
            HStack(spacing: 8) {
                Label(castleCountText, systemImage: "map.fill")
                Text("·")
                Label(conqueredCountText, systemImage: "flag.checkered")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(themeManager.worldAccent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .worldPanel(cornerRadius: 26)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }
}
