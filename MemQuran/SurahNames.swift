import Foundation

struct SurahNames {
    // surah-name-v2 font uses ligature strings
    static func getName(for surahNumber: Int) -> String {
        guard surahNumber >= 1 && surahNumber <= 114 else {
            return "surah001"
        }

        // Format as "surah001", "surah002", etc.
        return String(format: "surah%03d", surahNumber)
    }
}
