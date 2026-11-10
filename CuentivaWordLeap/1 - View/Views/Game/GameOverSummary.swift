import SwiftUI

/// Display values prepared by GameViewModel; this component owns no gameplay rules.
struct GameStatistic: Identifiable {
    let title: String
    let displayValue: String
    let symbol: String
    var detail: String = ""
    var id: String { title }
}

struct GameOverSummary: View {
    @Environment(ThemeManager.self) private var themeManager
    let statistics: [GameStatistic]
    let retry: () -> Void
    let leave: () -> Void

    var body: some View {
        ZStack {
            themeManager.worldShadow.opacity(0.58).ignoresSafeArea()
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        Image("WordLeapSkeleton")
                            .resizable().scaledToFit()
                            .frame(height: 132)
                            .shadow(color: .cyan.opacity(0.4), radius: 24)
                            .accessibilityHidden(true)

                        VStack(spacing: 5) {
                            Text("GAME OVER")
                                .font(.system(.largeTitle, design: .rounded, weight: .black))
                                .accessibilityAddTraits(.isHeader)
                            Text("A little less skin. A lot more story.")
                                .font(.subheadline).foregroundStyle(themeManager.worldSecondaryText)
                        }
                        .multilineTextAlignment(.center)

                        Text("THIS ADVENTURE")
                            .font(.caption.weight(.heavy)).tracking(3)
                            .foregroundStyle(themeManager.worldAccent)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(statistics) { statistic in
                                VStack(spacing: 5) {
                                    if statistic.symbol == "doubloon" {
                                        DoubloonArtwork(size: 25)
                                    } else {
                                        Image(systemName: statistic.symbol)
                                            .font(.title3).foregroundStyle(themeManager.worldAccent).frame(height: 25)
                                    }
                                    Text(statistic.displayValue)
                                        .font(.system(.title2, design: .rounded, weight: .heavy))
                                        .monospacedDigit()
                                    Text(statistic.title).font(.caption.weight(.semibold))
                                    if !statistic.detail.isEmpty {
                                        Text(statistic.detail).font(.caption2).foregroundStyle(themeManager.worldSecondaryText)
                                    }
                                }
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 100)
                                .padding(8)
                                .worldPanel(cornerRadius: 18)
                                .accessibilityElement(children: .combine)
                            }
                        }

                        Button(action: retry) {
                            Label("Continue from checkpoint", systemImage: "arrow.counterclockwise")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        }
                        .buttonStyle(.plain).foregroundStyle(themeManager.worldShadow)
                        .background(themeManager.worldAccent, in: Capsule())

                        Button("Back to Adventure", action: leave)
                            .font(.subheadline.weight(.semibold)).padding(12)
                    }
                    .foregroundStyle(themeManager.worldText)
                    .padding(24)
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}
