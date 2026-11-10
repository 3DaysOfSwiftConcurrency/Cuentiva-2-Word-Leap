import Foundation

actor CuentivaBookRepository {
    private let networkingManager: NetworkingManager
    private var cachedBooks: [StoryBook]?
    private let bundledLibraryURL: URL?
    private let githubStoriesURL: URL?

    init(
        networkingManager: NetworkingManager,
        bundledLibraryURL: URL? = Bundle.main.url(forResource: "Library", withExtension: "dat"),
        githubStoriesURL: URL? = URL(
            string: "https://raw.githubusercontent.com/3DaysOfSwift/Cuentiva/main/content/editorial/stories.txt"
        )
    ) {
        self.networkingManager = networkingManager
        self.bundledLibraryURL = bundledLibraryURL
        self.githubStoriesURL = githubStoriesURL
    }

    func books() throws -> [StoryBook] {
        if let cachedBooks { return cachedBooks }
        // Xcode copies files from the synchronized resource group to the app bundle root.
        guard let bundledURL = bundledLibraryURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let books = try BinaryStoryLibrary(url: bundledURL).books()
        cachedBooks = books
        return books
    }

    func refreshFromGitHub() async throws -> [StoryBook] {
        guard let githubStoriesURL else { throw CocoaError(.fileNoSuchFile) }
        let data = try await networkingManager.data(from: githubStoriesURL)
        let covers = Dictionary(try books().map { ($0.id, $0.cover) }, uniquingKeysWith: { first, _ in first })
        let books = try Self.decode(data, covers: covers)
        cachedBooks = books
        return books
    }

    static func decode(_ data: Data, covers: [String: StoryBookCover] = [:]) throws -> [StoryBook] {
        guard let manuscript = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        var books: [StoryBook] = []
        var header: (id: String, storyteller: String, title: String, englishTitle: String)?
        var passages: [String] = []
        var translations: [String] = []
        func finishBook() {
            if let header {
                books.append(StoryBook(id: header.id, storyteller: header.storyteller,
                    title: header.title, englishTitle: header.englishTitle, spanishPassages: passages,
                    englishPassages: translations, cover: covers[header.id] ?? StoryBookCover()))
            }
        }
        for line in manuscript.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix("@") {
                finishBook()
                let fields = line.dropFirst().split(separator: "|", maxSplits: 4).map(String.init)
                guard fields.count == 5 else { throw CocoaError(.fileReadCorruptFile) }
                header = (fields[0], fields[1], fields[2], fields[3])
                passages = []
                translations = []
            } else if line != "---", let spanish = line.split(separator: "|", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces), !spanish.isEmpty {
                passages.append(spanish)
                let parts = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                translations.append(parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "")
            }
        }
        finishBook()
        guard !books.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        return books
    }
}
