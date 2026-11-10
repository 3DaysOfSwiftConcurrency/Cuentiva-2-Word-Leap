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
            "A passage without a book. | An orphaned passage."
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
}
