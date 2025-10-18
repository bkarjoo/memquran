import Foundation

// MARK: - Audio API Response Models

/// Response model for AlQuran.cloud API
struct AudioVerseResponse: Codable, Sendable {
    let code: Int
    let status: String
    let data: AudioVerseData
}

/// Audio verse data containing the audio URL and metadata
struct AudioVerseData: Codable, Sendable {
    let number: Int
    let audio: String  // Primary audio URL (128 kbps)
    let audioSecondary: [String]?  // Alternative audio URLs (64 kbps)
    let text: String  // Arabic text of the verse
    let edition: AudioEdition
    let surah: AudioSurahInfo?
    let numberInSurah: Int
    let juz: Int?
    let manzil: Int?
    let page: Int?
    let ruku: Int?
    let hizbQuarter: Int?
    let sajda: Bool?
}

/// Information about the audio edition/reciter
struct AudioEdition: Codable, Sendable {
    let identifier: String  // e.g., "ar.alafasy"
    let language: String
    let name: String  // Arabic name
    let englishName: String
    let format: String  // "audio"
    let type: String  // "versebyverse"
    let direction: String?
}

/// Surah information in the audio response
struct AudioSurahInfo: Codable, Sendable {
    let number: Int
    let name: String  // Arabic name
    let englishName: String
    let englishNameTranslation: String
    let numberOfAyahs: Int
    let revelationType: String  // "Meccan" or "Medinan"
}

// MARK: - Audio Cache Model

/// Model for caching audio data in memory
public struct CachedAudioVerse: Sendable {
    public let surah: Int
    public let ayah: Int
    public let audioURL: URL
    public let text: String
    public let timestamp: Date

    public init(surah: Int, ayah: Int, audioURL: URL, text: String) {
        self.surah = surah
        self.ayah = ayah
        self.audioURL = audioURL
        self.text = text
        self.timestamp = Date()
    }

    /// Check if cache entry is still valid (within 1 hour)
    var isValid: Bool {
        return Date().timeIntervalSince(timestamp) < 3600  // 1 hour
    }
}

// MARK: - Error Types

public enum AudioServiceError: LocalizedError {
    case networkError(String)
    case invalidURL
    case decodingError(String)
    case noAudioAvailable
    case noInternetConnection

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidURL:
            return "Invalid URL for audio request"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .noAudioAvailable:
            return "No audio available for this verse"
        case .noInternetConnection:
            return "No internet connection. Audio mode requires an active connection."
        }
    }
}