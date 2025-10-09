import Foundation
import SwiftData

// MARK: - Word Progress (Core Model)

@Model
final class WordProgress {
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
    var wordProgress: WordProgress?

    init(content: String, wordProgress: WordProgress? = nil) {
        self.content = content
        self.createdAt = Date()
        self.wordProgress = wordProgress
    }
}

// MARK: - Word Link

@Model
final class WordLink {
    var url: String
    var title: String?
    var createdAt: Date
    var wordProgress: WordProgress?

    init(url: String, title: String? = nil, wordProgress: WordProgress? = nil) {
        self.url = url
        self.title = title
        self.createdAt = Date()
        self.wordProgress = wordProgress
    }
}

// MARK: - Word Mistake

@Model
final class WordMistake {
    var timestamp: Date
    var wordProgress: WordProgress?

    init(wordProgress: WordProgress? = nil) {
        self.timestamp = Date()
        self.wordProgress = wordProgress
    }
}

// MARK: - Word Interaction

@Model
final class WordInteraction {
    var timestamp: Date
    var wordProgress: WordProgress?

    init(wordProgress: WordProgress? = nil) {
        self.timestamp = Date()
        self.wordProgress = wordProgress
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
