import Foundation

actor CuentivaBookRepository {
    private static let maximumManuscriptSize = 5_000_000
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

    static func decode(_ manuscriptData: Data, covers: [String: StoryBookCover] = [:]) throws -> [StoryBook] {
        guard manuscriptData.count <= maximumManuscriptSize,
              let manuscript = String(data: manuscriptData, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var books: [StoryBook] = []
        var header: (id: String, storyteller: String, title: String, englishTitle: String)?
        var passages: [String] = []
        var translations: [String] = []
        func finishBook() throws {
            guard let header else { return }
            guard !header.id.isEmpty, !header.storyteller.isEmpty,
                  !header.title.isEmpty, !header.englishTitle.isEmpty,
                  !passages.isEmpty, passages.count == translations.count else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let book = StoryBook(id: header.id, storyteller: header.storyteller,
                title: header.title, englishTitle: header.englishTitle, spanishPassages: passages,
                englishPassages: translations, cover: covers[header.id] ?? StoryBookCover())
            guard book.platformCount > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            books.append(book)
        }
        for line in manuscript.split(whereSeparator: \.isNewline).map(String.init) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("@") {
                try finishBook()
                let fields = trimmedLine.dropFirst()
                    .split(separator: "|", maxSplits: 4, omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard fields.count == 5, fields.allSatisfy({ !$0.isEmpty }) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                header = (fields[0], fields[1], fields[2], fields[3])
                passages = []
                translations = []
            } else if trimmedLine != "---",
                      let spanish = trimmedLine.split(separator: "|", maxSplits: 1).first?
                        .trimmingCharacters(in: .whitespaces),
                      !spanish.isEmpty {
                guard header != nil else { throw CocoaError(.fileReadCorruptFile) }
                passages.append(spanish)
                let parts = trimmedLine.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                translations.append(parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "")
            }
        }
        try finishBook()
        guard !books.isEmpty, Set(books.map(\.id)).count == books.count else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return books
    }
}
