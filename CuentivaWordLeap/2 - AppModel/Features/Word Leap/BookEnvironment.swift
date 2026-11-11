/// A book can own bespoke scenery or share a reusable environment pack.
/// Selection uses stable book identity, never the catalogue's current order.
enum BookEnvironment: String, CaseIterable, Sendable {
    case coast, roots, railway, puddle, observatory, harbour
    case theatre, orchard, storm, letters, skyFalls

    /// Fixed assignments preserve a book's scenery across retries, title edits and catalogue refreshes.
    /// Sky Falls introduces books 1–10; new packs debut every five books from 11,
    /// with Letters reserved for book 52. Between debuts, earlier packs rotate.
    static func forBook(id: String) -> BookEnvironment {
        switch id {
        // Books 11, 13, 15, 18, 22, 27, 33, 40, 49.
        case "rainy-roof", "first-stitch", "empty-wallet", "sunday-pot", "thoughtful-yes",
             "garden-colours", "ten-pages", "cube-among-stars", "verb-querer":
            .coast
        // Books 16, 19, 23, 28, 34, 42.
        case "shared-table", "film-conversation", "enough-on-paper", "potato-basket",
             "metaphor-not-law", "travelling-sun":
            .roots
        // Books 21, 25, 30, 37, 45.
        case "first-invitation", "travelling-seed", "body-care", "four-years-road", "table-for-three":
            .railway
        // Books 26, 32, 39, 48.
        case "tomato-question", "pause-before-plan", "cow-two-names", "verb-estar":
            .puddle
        // Books 31, 38, 47.
        case "water-toast", "calendar-of-later", "verb-ser":
            .observatory
        // Books 36, 44.
        case "brand-from-within", "wrong-suitcase":
            .harbour
        // Books 41, 50.
        case "feet-on-earth", "nearby-bangkok":
            .theatre
        // Book 46.
        case "last-train-scene":
            .orchard
        // Book 51.
        case "nearby-pattaya":
            .storm
        // Book 52.
        case "nearby-thailand":
            .letters
        default:
            .skyFalls
        }
    }

    var backdropAssetName: String {
        switch self {
        case .coast: "CoastBackdrop"
        case .roots: "RootsBackdrop"
        case .railway: "RailwayBackdrop"
        case .puddle: "PuddleBackdrop"
        case .observatory: "ObservatoryBackdrop"
        case .harbour: "HarbourBackdrop"
        case .theatre: "TheatreBackdrop"
        case .orchard: "OrchardBackdrop"
        case .storm: "StormBackdrop"
        case .letters: "LettersBackdrop"
        case .skyFalls: "SkyFallsBackdrop"
        }
    }
}
