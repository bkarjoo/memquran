import Foundation
import SwiftData

// MARK: - Word Data (Core Model)

@Model
final class WordData {
    var surahNumber: Int
    var ayahNumber: Int
    var wordPosition: Int

    // Single values
    var isBookmarked: Bool
    var isDemarcationPoint: Bool
    var isHidden: Bool

    // Relationships (one-to-many)
    @Relationship(deleteRule: .cascade) var notes: [WordNote]
    @Relationship(deleteRule: .cascade) var links: [WordLink]
    @Relationship(deleteRule: .cascade) var mistakes: [WordMistake]
    @Relationship(deleteRule: .cascade) var interactions: [WordInteraction]

    init(surahNumber: Int, ayahNumber: Int, wordPosition: Int) {
        self.surahNumber = surahNumber
        self.ayahNumber = ayahNumber
        self.wordPosition = wordPosition
        self.isBookmarked = false
        self.isDemarcationPoint = false
        self.isHidden = false
        self.notes = []
        self.links = []
        self.mistakes = []
        self.interactions = []
    }
}

// MARK: - Word Note

@Model
final class WordNote {
    var content: String
    var createdAt: Date
    var wordData: WordData?

    init(content: String, wordData: WordData? = nil) {
        self.content = content
        self.createdAt = Date()
        self.wordData = wordData
    }
}

// MARK: - Word Link

@Model
final class WordLink {
    var url: String
    var title: String?
    var createdAt: Date
    var wordData: WordData?

    init(url: String, title: String? = nil, wordData: WordData? = nil) {
        self.url = url
        self.title = title
        self.createdAt = Date()
        self.wordData = wordData
    }
}

// MARK: - Word Mistake

@Model
final class WordMistake {
    var timestamp: Date
    var wordData: WordData?

    init(wordData: WordData? = nil) {
        self.timestamp = Date()
        self.wordData = wordData
    }
}

// MARK: - Word Interaction

@Model
final class WordInteraction {
    var timestamp: Date
    var wordData: WordData?

    init(wordData: WordData? = nil) {
        self.timestamp = Date()
        self.wordData = wordData
    }
}

// MARK: - Legacy Bookmark (for migration)

@Model
final class Bookmark {
    var surahNumber: Int
    var ayahNumber: Int
    var createdAt: Date

    init(surahNumber: Int, ayahNumber: Int) {
        self.surahNumber = surahNumber
        self.ayahNumber = ayahNumber
        self.createdAt = Date()
    }
}
