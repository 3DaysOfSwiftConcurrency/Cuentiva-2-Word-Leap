import Foundation

struct LevelPlan: Sendable {
    let book: StoryBook
    let words: [String]
    let verbIndices: Set<Int>
    let verbCountingAvailable: Bool

    init(
        book: StoryBook,
        words: [String],
        verbIndices: Set<Int> = [],
        verbCountingAvailable: Bool = true
    ) {
        self.book = book
        self.words = words
        self.verbIndices = verbIndices
        self.verbCountingAvailable = verbCountingAvailable
    }
}

actor LevelPlanBuilder {
    private let vocabularyURL: URL?
    private var cachedVerbForms: Set<String>?

    init(vocabularyURL: URL? = Bundle.main.url(forResource: "verbs", withExtension: "json")) {
        self.vocabularyURL = vocabularyURL
    }

    func makePlan(for book: StoryBook) -> LevelPlan {
        let words = book.spanishPassages.flatMap(SpanishWordTokenizer.platformTokens)
        guard let forms = verbForms() else {
            // The book remains playable, but the UI must not present an unavailable count as zero.
            return LevelPlan(book: book, words: words, verbCountingAvailable: false)
        }
        let verbs = Set(words.indices.filter { forms.contains(words[$0].lowercased()) })
        return LevelPlan(book: book, words: words, verbIndices: verbs)
    }

    private func verbForms() -> Set<String>? {
        if let cachedVerbForms { return cachedVerbForms }
        guard let vocabularyURL else { return nil }
        do {
            let entries = try JSONDecoder().decode([VerbEntry].self, from: Data(contentsOf: vocabularyURL))
            // Reuse Verbos's teaching vocabulary, including the lexical verb in reflexive phrases.
            let forms = entries.flatMap { [$0.id, $0.participle, $0.gerund] + $0.forms.values.flatMap { $0 } }
            let vocabulary = Set(forms.compactMap { $0.split(separator: " ").last?.lowercased() })
            guard !vocabulary.isEmpty else { return nil }
            cachedVerbForms = vocabulary
            return vocabulary
        } catch {
            // Optional learning statistic unavailable; no fabricated count or blocked level.
            return nil
        }
    }

    private struct VerbEntry: Decodable {
        let id: String
        let participle: String
        let gerund: String
        let forms: [String: [String]]
    }
}
