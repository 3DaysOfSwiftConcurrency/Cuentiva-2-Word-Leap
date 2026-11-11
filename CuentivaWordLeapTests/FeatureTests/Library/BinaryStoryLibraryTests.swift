import Foundation
import Testing
@testable import CuentivaWordLeap

struct BinaryStoryLibraryTests {
    private var resources: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }

    private func resource(_ name: String, _ ext: String) throws -> Data {
        try Data(contentsOf: #require(resources.url(forResource: name, withExtension: ext)))
    }

    @Test func binaryPreservesEveryBookPassageTranslationAndCoverInOrder() throws {
        let covers = try JSONDecoder().decode([String: StoryBookCover].self,
            from: resource("metadata", "json"))
        let original = try CuentivaBookRepository.decode(resource("stories", "txt"), covers: covers)
        let binaryLibrary = try BinaryStoryLibrary(data: resource("Library", "dat"))
        let compiled = try binaryLibrary.books()
        #expect(binaryLibrary.bookCount == 52)
        #expect(compiled == original)
        #expect(compiled.map(\.platformCount) == original.map(\.platformCount))
        #expect(throws: CocoaError.self) { try binaryLibrary.book(at: -1) }
        #expect(throws: CocoaError.self) { try binaryLibrary.book(at: binaryLibrary.bookCount) }
    }

    @Test(arguments: [0, 7, 15, 16, 167])
    func truncatedDataIsRejected(length: Int) throws {
        let libraryData = try resource("Library", "dat")
        #expect(throws: CocoaError.self) {
            try BinaryStoryLibrary(data: Data(libraryData.prefix(length))).books()
        }
    }

    @Test(arguments: ["magic", "version", "count", "stringOffset", "stringLength",
                      "utf8", "sentenceCount", "requiredSentences", "optionalSentences",
                      "duplicateID", "unplayablePassage"])
    func corruptTablesAreRejectedWithoutReadingOutsideTheFile(fault: String) throws {
        var libraryData = try resource("Library", "dat")
        switch fault {
        case "magic": libraryData[0] = 0
        case "version": setWord(3, at: 8, in: &libraryData)
        case "count": setWord(.max, at: 12, in: &libraryData)
        case "stringOffset": setWord(.max, at: 16, in: &libraryData)
        case "stringLength": setWord(.max, at: 20, in: &libraryData)
        case "utf8":
            let offset = libraryData.withUnsafeBytes {
                UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: 16, as: UInt32.self))
            }
            libraryData[Int(offset)] = 0xff
        case "sentenceCount": setWord(.max, at: 16 + 100, in: &libraryData)
        case "requiredSentences": setWord(.max, at: 16 + 96, in: &libraryData)
        case "optionalSentences": setWord(1, at: 16 + 116, in: &libraryData)
        case "duplicateID":
            let firstID = libraryData.subdata(in: 16..<24)
            libraryData.replaceSubrange(168..<176, with: firstID)
        case "unplayablePassage":
            let sentenceTableOffset = Int(word(at: 16 + 96, in: libraryData))
            let spanishOffset = Int(word(at: sentenceTableOffset + 8, in: libraryData))
            let spanishLength = Int(word(at: sentenceTableOffset + 12, in: libraryData))
            libraryData.replaceSubrange(
                spanishOffset..<(spanishOffset + spanishLength),
                with: repeatElement(UInt8(ascii: "!"), count: spanishLength)
            )
        default: Issue.record("Unexpected corruption case")
        }
        #expect(throws: CocoaError.self) { try BinaryStoryLibrary(data: libraryData).books() }
    }

    private func setWord(_ value: UInt32, at offset: Int, in libraryData: inout Data) {
        for byte in 0..<4 {
            libraryData[offset + byte] = UInt8(truncatingIfNeeded: value >> (byte * 8))
        }
    }

    private func word(at offset: Int, in libraryData: Data) -> UInt32 {
        libraryData.withUnsafeBytes {
            UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }
    }
}
