import SwiftUI

struct DoubloonArtwork: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [CuentivaArtwork.coinHighlight, CuentivaArtwork.coinGold,
                CuentivaArtwork.coinShadow], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(CuentivaArtwork.coinShadow, lineWidth: size * 0.035)
            Circle().inset(by: size * 0.09)
                .strokeBorder(CuentivaArtwork.coinHighlight.opacity(0.9), lineWidth: size * 0.025)
            Circle().inset(by: size * 0.14)
                .strokeBorder(CuentivaArtwork.coinShadow.opacity(0.5), lineWidth: size * 0.018)
            Image(systemName: "book.closed.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(CuentivaArtwork.coinShadow)
                .shadow(color: CuentivaArtwork.coinHighlight, radius: 0, x: 0, y: size * 0.015)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
