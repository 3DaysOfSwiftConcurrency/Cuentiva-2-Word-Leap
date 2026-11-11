import Foundation

/// Reads Cuentiva's version-two CUENLIB offset tables and UTF-8 strings.
/// Word Leap uses the story/cover fields, not the reader app's learning metadata.
struct BinaryStoryLibrary: Sendable {
    private let libraryData: Data
    let bookCount: Int
    private static let bookStride = 152

    init(data: Data) throws {
        guard data.count >= 16, data.count <= 50_000_000,
              data.prefix(8) == Data("CUENLIB\0".utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        libraryData = data
        let version = Self.word(data, at: 8)
        bookCount = Int(Self.word(data, at: 12))
        guard version == 2, bookCount > 0, bookCount <= 20_000,
              bookCount <= (data.count - 16) / Self.bookStride else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    init(url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= 50_000_000 else { throw CocoaError(.fileReadCorruptFile) }
        try self.init(data: Data(contentsOf: url))
    }

    func books() throws -> [StoryBook] {
        let books = try (0..<bookCount).map(book(at:))
        guard Set(books.map(\.id)).count == books.count else { throw CocoaError(.fileReadCorruptFile) }
        return books
    }

    func book(at bookIndex: Int) throws -> StoryBook {
        guard (0..<bookCount).contains(bookIndex) else { throw CocoaError(.fileReadCorruptFile) }
        let bookRecordOffset = 16 + bookIndex * Self.bookStride
        let storyPassages = try sentences(at: bookRecordOffset + 96, optional: false)
            + sentences(at: bookRecordOffset + 112, optional: true)
            + sentences(at: bookRecordOffset + 140, optional: true)
        let book = try StoryBook(id: text(at: bookRecordOffset),
            storyteller: text(at: bookRecordOffset + 24),
            title: text(at: bookRecordOffset + 8), englishTitle: text(at: bookRecordOffset + 16),
            spanishPassages: storyPassages.map(\.spanish),
            englishPassages: storyPassages.map(\.english),
            cover: StoryBookCover(level: text(at: bookRecordOffset + 32),
                                  symbol: text(at: bookRecordOffset + 40),
                                  palette: Int(uint(at: bookRecordOffset + 88))))
        guard !book.id.isEmpty, !book.title.isEmpty, !book.englishTitle.isEmpty,
              !book.storyteller.isEmpty, !storyPassages.isEmpty,
              storyPassages.allSatisfy({ !$0.spanish.isEmpty }), book.platformCount > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return book
    }

    private func sentences(
        at sentenceListDescriptorOffset: Int,
        optional: Bool
    ) throws -> [(spanish: String, english: String)] {
        let offset = try uint(at: sentenceListDescriptorOffset)
        let sentenceCount = Int(try uint(at: sentenceListDescriptorOffset + 4))
        if offset == .max {
            guard optional, sentenceCount == 0 else { throw CocoaError(.fileReadCorruptFile) }
            return []
        }
        let sentenceTableOffset = Int(offset)
        try check(sentenceTableOffset, length: 0)
        guard sentenceCount <= 10_000,
              sentenceCount <= (libraryData.count - sentenceTableOffset) / 32 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try (0..<sentenceCount).map { index in
            let sentenceRecordOffset = sentenceTableOffset + index * 32
            return (
                try text(at: sentenceRecordOffset + 8),
                try text(at: sentenceRecordOffset + 16)
            )
        }
    }

    private func text(at textDescriptorOffset: Int) throws -> String {
        let offset = Int(try uint(at: textDescriptorOffset))
        let length = Int(try uint(at: textDescriptorOffset + 4))
        try check(offset, length: length)
        guard let text = String(data: libraryData.subdata(in: offset..<(offset + length)), encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return text
    }

    private func uint(at offset: Int) throws -> UInt32 {
        try check(offset, length: 4)
        return Self.word(libraryData, at: offset)
    }

    private func check(_ offset: Int, length: Int) throws {
        guard offset >= 0, length >= 0, offset <= libraryData.count,
              length <= libraryData.count - offset else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    private static func word(_ libraryData: Data, at offset: Int) -> UInt32 {
        libraryData.withUnsafeBytes {
            UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }
    }
}
