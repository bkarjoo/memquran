import Foundation
import SwiftData

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
