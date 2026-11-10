import SwiftUI

/// An illustrated home on the trail. Access and numbering arrive from the feature.
struct StoryOutpost: View {
    @Environment(ThemeManager.self) private var themeManager
    let castle: AdventureCastlePresentation
    private let actionDiameter: CGFloat = 48

    private var isLeading: Bool { !castle.number.isMultiple(of: 2) }
    private var alignment: HorizontalAlignment { isLeading ? .leading : .trailing }
    private var frameAlignment: Alignment { isLeading ? .leading : .trailing }
    private var textAlignment: TextAlignment { isLeading ? .leading : .trailing }
    var body: some View {
        ZStack {
            MapTrail(isLeading: isLeading)
                .stroke(themeManager.worldAccent.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 9]))
                .padding(.horizontal, 36)
                .accessibilityHidden(true)

            VStack(alignment: alignment, spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    Image("LettersLandmark")
                        .resizable().scaledToFit()
                        .frame(width: 192, height: 232)
                        .saturation(castle.isUnlocked ? 1 : 0.25)
                        .brightness(castle.isUnlocked ? 0 : -0.13)
                        .shadow(color: themeManager.worldAccent.opacity(castle.isUnlocked ? 0.30 : 0.06),
                            radius: 20, y: 6)

                    Image(castle.characterAssetName)
                        .resizable().scaledToFit()
                        .frame(width: 100, height: 112)
                        .shadow(color: .black.opacity(0.65), radius: 8, y: 5)
                        .offset(x: 26, y: 6)
                }
                .overlay(alignment: .topLeading) {
                    Text(castle.numberText)
                        .font(.system(.title2, design: .serif, weight: .bold).monospacedDigit())
                        .foregroundStyle(themeManager.worldText)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(themeManager.worldPanel, in: Circle())
                        .overlay(Circle().stroke(themeManager.worldAccent, lineWidth: 2))
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
                        .offset(x: -8, y: 12)
                }
                .padding(.horizontal, 16)
                .accessibilityHidden(true)

                VStack(alignment: alignment, spacing: 6) {
                    Text(castle.heading)
                        .font(.caption2.weight(.heavy)).tracking(2)
                        .foregroundStyle(themeManager.worldAccent)
                    Text(castle.book.title)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(themeManager.worldText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(castle.book.englishTitle)
                        .font(.subheadline)
                        .foregroundStyle(themeManager.worldSecondaryText)
                    Label(castle.statusText, systemImage: castle.statusSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.worldAccent)
                    .padding(.top, 3)
                }
                .multilineTextAlignment(textAlignment)
                .padding(.top, actionDiameter / 2)
                .padding(18)
                .frame(maxWidth: 280, alignment: frameAlignment)
                .worldPanel()
                .overlay(alignment: .top) {
                    Image(systemName: castle.actionSymbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.worldShadow)
                        .frame(width: actionDiameter, height: actionDiameter)
                        .background(themeManager.worldAccent, in: Circle())
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                        .offset(y: -actionDiameter / 2)
                        .accessibilityHidden(true)
                }
                // Reserve the protruding half so the action clears the character artwork.
                .padding(.top, actionDiameter / 2 + 12)
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(castle.accessibilityLabel)
        .accessibilityHint(castle.accessibilityHint)
    }
}

private struct MapTrail: Shape {
    let isLeading: Bool

    func path(in rect: CGRect) -> Path {
        let near = isLeading ? rect.maxX * 0.22 : rect.maxX * 0.78
        let far = isLeading ? rect.maxX * 0.78 : rect.maxX * 0.22
        return Path { path in
            path.move(to: CGPoint(x: far, y: rect.minY))
            path.addCurve(to: CGPoint(x: near, y: rect.maxY),
                control1: CGPoint(x: far, y: rect.height * 0.55),
                control2: CGPoint(x: near, y: rect.height * 0.45))
        }
    }
}
