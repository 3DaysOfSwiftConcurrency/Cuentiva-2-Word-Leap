import SpriteKit
import SwiftUI

struct GameView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: GameViewModel
    @State private var isReadingBook = false

    init(book: StoryBook) {
        _viewModel = State(initialValue: GameViewModel(book: book))
    }

    var body: some View {
        ZStack {
            if let scene = viewModel.scene {
                SpriteView(scene: scene, isPaused: scenePhase != .active, options: [.shouldCullNonVisibleNodes])
                    .allowsHitTesting(!viewModel.isDeathPresented && !viewModel.isLevelComplete)
                    .ignoresSafeArea()
            } else {
                WorldBackdrop(assetName: viewModel.currentBook.backgroundAssetName, shade: 0.3)
                if let error = viewModel.preparationError {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill").font(.largeTitle)
                        Text(error).multilineTextAlignment(.center)
                        Button("Return to Adventure", action: leave)
                            .buttonStyle(.borderedProminent)
                    }
                    .foregroundStyle(themeManager.worldText)
                    .padding(32)
                    .worldPanel()
                    .padding(24)
                } else {
                    VStack(spacing: 18) {
                        Image(viewModel.loadingCharacterAssetName)
                            .resizable().scaledToFit().frame(height: 140)
                            .accessibilityHidden(true)
                        ProgressView("Opening \(viewModel.currentBook.title)…")
                            .tint(themeManager.worldAccent)
                    }
                    .foregroundStyle(themeManager.worldText)
                    .padding(28)
                    .worldPanel()
                    .padding(24)
                }
            }

            VStack(spacing: 16) {
                GameHUD(
                    bookTitle: viewModel.currentBook.title,
                    platformProgress: viewModel.platformProgress,
                    collectedDoubloonText: viewModel.collectedDoubloonText,
                    collectedDoubloonAccessibilityLabel: viewModel.collectedDoubloonAccessibilityLabel,
                    leave: leave
                )
                Spacer()
                if viewModel.scene != nil, !viewModel.isLevelComplete {
                    GameReadingCard(text: viewModel.readingCardText)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .allowsHitTesting(!viewModel.isDeathPresented)
            .accessibilityHidden(viewModel.isDeathPresented)

            if viewModel.isBookRevealed {
                Color.black.opacity(0.32).ignoresSafeArea().allowsHitTesting(false)
                BookCompletionReveal(cover: viewModel.completedBookCover, title: viewModel.completionTitle,
                    doubloonText: viewModel.completionDoubloonText,
                    primaryActionTitle: viewModel.completionActionTitle, hasNextLevel: viewModel.nextBook != nil,
                    read: { isReadingBook = true }, next: viewModel.startNextLevel, leave: leave)
                    .padding(.top, 70)
                    .transition(.opacity)
            } else if viewModel.isLevelComplete {
                Text(viewModel.completionTitle)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .multilineTextAlignment(.center).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 8)
                    .padding(24).allowsHitTesting(false)
            }

            if viewModel.isDeathPresented {
                GameOverSummary(statistics: viewModel.gameOverStatistics, retry: retry, leave: leave)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.isDeathPresented)
        .animation(.easeOut(duration: 0.3), value: viewModel.isBookRevealed)
        .onChange(of: scenePhase) { _, _ in viewModel.scene?.resetFrameClock() }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.prepare(reduceMotion: reduceMotion).value
        }
        .onDisappear { viewModel.leaveLevel() }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isReadingBook) {
            NavigationStack {
                CompletedBookPagesView(book: viewModel.currentBook)
                    .navigationTitle(viewModel.currentBook.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .worldNavigation()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isReadingBook = false }
                        }
                    }
            }
            .tint(themeManager.worldAccent)
        }
    }

    private func leave() {
        viewModel.leaveLevel()
        dismiss()
    }

    private func retry() {
        viewModel.retry()
    }
}

private struct GameHUD: View {
    @Environment(ThemeManager.self) private var themeManager
    let bookTitle: String
    let platformProgress: String
    let collectedDoubloonText: String
    let collectedDoubloonAccessibilityLabel: String
    let leave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: leave) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .worldPanel(cornerRadius: 22)
            }
            .foregroundStyle(themeManager.worldAccent)
            .accessibilityLabel("Leave adventure")

            VStack(spacing: 2) {
                Text(bookTitle).font(.headline.weight(.heavy)).lineLimit(1)
                Text(platformProgress)
                    .font(.caption.weight(.bold)).monospacedDigit().opacity(0.82)
            }
            .foregroundStyle(themeManager.worldText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .worldPanel(cornerRadius: 24)

            HStack(spacing: 4) {
                DoubloonArtwork(size: 28)
                Text(collectedDoubloonText)
                    .font(.headline.monospacedDigit()).foregroundStyle(themeManager.worldText)
            }
            .padding(9)
            .worldPanel(cornerRadius: 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(collectedDoubloonAccessibilityLabel)
        }
    }
}

private struct GameReadingCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundStyle(themeManager.worldText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .worldPanel(cornerRadius: 24)
    }
}
