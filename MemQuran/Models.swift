import Foundation
import SwiftData

// MARK: - Word Data (Core Model)

@Model
final class WordData {
    // CloudKit-compatible: all properties have default values
    var surahNumber: Int = 0
    var ayahNumber: Int = 0
    var wordPosition: Int = 0

    // Layout properties
    var lineNumber: Int = 0
    var positionInLine: Int = 0

    // Single values
    var isBookmarked: Bool = false
    var isDemarcationPoint: Bool = false

    // Relationships (one-to-many) - CloudKit requires optional relationships
    @Relationship(deleteRule: .cascade) var notes: [WordNote]?
    @Relationship(deleteRule: .cascade) var links: [WordLink]?
    @Relationship(deleteRule: .cascade) var mistakes: [WordMistake]?
    @Relationship(deleteRule: .cascade) var interactions: [WordInteraction]?
    @Relationship(deleteRule: .cascade) var bookmarks: [WordBookmark]?

    init(surahNumber: Int, ayahNumber: Int, wordPosition: Int, lineNumber: Int = 0, positionInLine: Int = 0) {
        self.surahNumber = surahNumber
        self.ayahNumber = ayahNumber
        self.wordPosition = wordPosition
        self.lineNumber = lineNumber
        self.positionInLine = positionInLine
        self.isBookmarked = false
        self.isDemarcationPoint = false
        self.notes = []
        self.links = []
        self.mistakes = []
        self.interactions = []
        self.bookmarks = []
    }
}

// MARK: - Word Note

@Model
final class WordNote {
    // CloudKit-compatible: all properties have default values
    var content: String = ""
    var createdAt: Date = Date()
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
    // CloudKit-compatible: all properties have default values
    var url: String = ""
    var title: String?
    var createdAt: Date = Date()
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
    // CloudKit-compatible: all properties have default values
    var timestamp: Date = Date()
    var wordData: WordData?

    init(wordData: WordData? = nil) {
        self.timestamp = Date()
        self.wordData = wordData
    }
}

// MARK: - Word Interaction

@Model
final class WordInteraction {
    // CloudKit-compatible: all properties have default values
    var timestamp: Date = Date()
    var wordData: WordData?

    init(wordData: WordData? = nil) {
        self.timestamp = Date()
        self.wordData = wordData
    }
}

// MARK: - Bookmark Category

enum BookmarkCategory: String, Codable, CaseIterable {
    case review = "Review"
    case memorization = "Memorization"
    case recitation = "Recitation"
    case research = "Research"

    var icon: String {
        switch self {
        case .memorization: return "brain.head.profile"
        case .review: return "arrow.clockwise"
        case .recitation: return "book.closed"
        case .research: return "magnifyingglass"
        }
    }

    var color: String {
        switch self {
        case .memorization: return "blue"
        case .review: return "green"
        case .recitation: return "purple"
        case .research: return "orange"
        }
    }
}

// MARK: - Word Bookmark

@Model
final class WordBookmark {
    // CloudKit-compatible: all properties have default values
    var surahNumber: Int = 0
    var ayahNumber: Int = 0
    var wordPosition: Int = 0
    var category: String = BookmarkCategory.memorization.rawValue  // Raw value of BookmarkCategory
    var bookmarkDescription: String = ""
    var createdAt: Date = Date()
    var wordData: WordData?

    init(surahNumber: Int, ayahNumber: Int, wordPosition: Int, category: BookmarkCategory, description: String = "", wordData: WordData? = nil) {
        self.surahNumber = surahNumber
        self.ayahNumber = ayahNumber
        self.wordPosition = wordPosition
        self.category = category.rawValue
        self.bookmarkDescription = description
        self.createdAt = Date()
        self.wordData = wordData
    }

    var categoryEnum: BookmarkCategory {
        BookmarkCategory(rawValue: category) ?? .memorization
    }
}
