import Foundation

public struct MushafLine {
    public let pageNumber: Int
    public let lineNumber: Int
    public let lineType: String  // "ayah", "surah_name", "basmallah"
    public let isCentered: Bool
    public let firstWordId: Int?
    public let lastWordId: Int?
    public let surahNumber: Int?

    public init(pageNumber: Int, lineNumber: Int, lineType: String, isCentered: Bool, firstWordId: Int?, lastWordId: Int?, surahNumber: Int?) {
        self.pageNumber = pageNumber
        self.lineNumber = lineNumber
        self.lineType = lineType
        self.isCentered = isCentered
        self.firstWordId = firstWordId
        self.lastWordId = lastWordId
        self.surahNumber = surahNumber
    }
}

public struct QuranWord {
    public let id: Int
    public let location: String  // "surah:ayah:word"
    public let surah: Int
    public let ayah: Int
    public let word: Int
    public let text: String

    public init(id: Int, location: String, surah: Int, ayah: Int, word: Int, text: String) {
        self.id = id
        self.location = location
        self.surah = surah
        self.ayah = ayah
        self.word = word
        self.text = text
    }
}
