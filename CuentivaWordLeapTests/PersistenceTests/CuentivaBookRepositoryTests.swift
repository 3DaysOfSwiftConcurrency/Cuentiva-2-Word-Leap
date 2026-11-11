import Foundation
import Testing
@testable import CuentivaWordLeap

struct CuentivaBookRepositoryTests {
    @Test func decodesBooksAndSpanishPassages() throws {
        let source = """
        @mora-01|Mora|La corona|The Crown|A short tale
        ---
        Mora encuentra una corona. | Mora finds a crown.
        """

        let cover = StoryBookCover(level: "A2", symbol: "crown", palette: 3)
        let books = try CuentivaBookRepository.decode(Data(source.utf8), covers: ["mora-01": cover])

        #expect(books.count == 1)
        #expect(books[0].title == "La corona")
        #expect(books[0].spanishPassages == ["Mora encuentra una corona."])
        #expect(books[0].englishPassages == ["Mora finds a crown."])
        #expect(books[0].cover == cover)
    }

    @Test func rejectsIncompleteAndDuplicateRemoteBooks() {
        let malformedManuscripts = [
            "@missing-passages|Pipa|Sin historia|No Story|Description",
            "@missing-title|Pipa||No Title|Description\nPipa salta. | Pipa jumps.",
            "@whitespace-id|   |Un cuento|A Story|Description\nPipa salta. | Pipa jumps.",
            "@duplicate|Pipa|Uno|One|Description\nPipa salta. | Pipa jumps.\n"
                + "@duplicate|Mora|Dos|Two|Description\nMora mira. | Mora looks.",
            "A passage without a book. | An orphaned passage.",
            "@no-words|Pipa|Sin palabras|No Words|Description\n!!! | No playable words.",
            "@missing-spanish|Pipa|Incompleto|Incomplete|Description\nHola. | Hello.\n| English only."
        ]

        for manuscript in malformedManuscripts {
            #expect(throws: CocoaError.self) {
                try CuentivaBookRepository.decode(Data(manuscript.utf8))
            }
        }
    }

    @Test func trimsRemoteHeaderFieldsAndRejectsOversizedManuscripts() throws {
        let source = "  @ pipa-01 | Pipa | Un cuento | A Story | Description  \nHola. | Hello."
        let books = try CuentivaBookRepository.decode(Data(source.utf8))

        #expect(books.first?.id == "pipa-01")
        #expect(books.first?.title == "Un cuento")
        #expect(throws: CocoaError.self) {
            try CuentivaBookRepository.decode(Data(repeating: 0x20, count: 5_000_001))
        }
    }

    @Test @MainActor
    func rejectsRemoteProgressionChangesAndPreservesTheEstablishedBooks() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let incompleteRemote = Data(
            "@one|Pipa|Uno remoto|Remote One|A1\nHola.|Hello.\n".utf8
        )
        let reorderedRemote = Data("""
        @two|Musgo|Dos remoto|Remote Two|A1
        Corre.|Run.
        @one|Pipa|Uno remoto|Remote One|A1
        Hola.|Hello.
        @three|Mora|Tres remoto|Remote Three|A1
        Mira.|Look.
        """.utf8)

        for invalidRemote in [incompleteRemote, reorderedRemote] {
            let repository = CuentivaBookRepository(
                networkingManager: NetworkingManager { _ in invalidRemote },
                bundledLibraryURL: fixture.directory.appendingPathComponent("Library.dat")
            )
            let establishedBooks = try await repository.books()

            await #expect(throws: CocoaError.self) {
                try await repository.refreshFromGitHub()
            }

            let retainedBooks = try await repository.books()
            #expect(retainedBooks.map(\.id) == establishedBooks.map(\.id))
            #expect(retainedBooks.map(\.title) == ["Uno", "Dos", "Tres"])
        }
    }

    @Test @MainActor
    func acceptsContentUpdatesAndBooksAppendedAfterTheEstablishedProgression() async throws {
        let fixture = try AdventureTestFixture()
        defer { try? fixture.cleanUp() }
        let expandedRemote = Data("""
        @one|Pipa|Uno remoto|Remote One|A1
        Hola.|Hello.
        @two|Musgo|Dos remoto|Remote Two|A1
        Corre.|Run.
        @three|Mora|Tres remoto|Remote Three|A1
        Mira.|Look.
        @four|Luma|Cuatro|Four|A1
        Salta.|Jump.
        """.utf8)
        let repository = CuentivaBookRepository(
            networkingManager: NetworkingManager { _ in expandedRemote },
            bundledLibraryURL: fixture.directory.appendingPathComponent("Library.dat")
        )

        let refreshedBooks = try await repository.refreshFromGitHub()

        #expect(refreshedBooks.map(\.id) == ["one", "two", "three", "four"])
        #expect(refreshedBooks.first?.title == "Uno remoto")
    }
}
