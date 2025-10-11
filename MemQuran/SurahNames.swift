import Foundation

struct SurahNames {
    // PUA (Private Use Area) Unicode characters for QPC surah name font (surah-name-v4.ttf)
    // Each surah name is mapped to U+E000 + surah_number
    static func getName(for surahNumber: Int) -> String {
        guard surahNumber >= 1 && surahNumber <= 114 else {
            return "\u{E000}"  // Generic surah icon
        }

        // Convert surah number to PUA character
        let code = 0xE000 + surahNumber
        guard let scalar = Unicode.Scalar(code) else {
            return "\u{E000}"
        }

        return String(Character(scalar))
    }
}
