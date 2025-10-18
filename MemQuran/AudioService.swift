import Foundation
import Network

/// Service for fetching Quran audio from AlQuran.cloud API
public class AudioService {
    // MARK: - Properties

    private let baseURL = "https://api.alquran.cloud/v1"
    private let reciterIdentifier = "ar.alafasy"  // Mishary Alafasy
    private let session = URLSession.shared
    private var audioCache: [String: CachedAudioVerse] = [:]
    private let maxCacheSize = 10  // Maximum verses to keep in cache
    private let networkMonitor = NWPathMonitor()
    private var isConnected = true

    // MARK: - Singleton

    public static let shared = AudioService()

    private init() {
        setupNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = (path.status == .satisfied)
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }

    // MARK: - Public Methods

    /// Fetch audio for a specific verse
    /// - Parameters:
    ///   - surah: Surah number (1-114)
    ///   - ayah: Ayah number within the surah
    ///   - completion: Completion handler with result
    public func fetchVerseAudio(
        surah: Int,
        ayah: Int,
        completion: @escaping (Result<CachedAudioVerse, AudioServiceError>) -> Void
    ) {
        // Check network connectivity
        guard isConnected else {
            completion(.failure(.noInternetConnection))
            return
        }

        // Check cache first
        let cacheKey = "\(surah):\(ayah)"
        if let cached = audioCache[cacheKey], cached.isValid {
            completion(.success(cached))
            return
        }

        // Build URL for the API request
        let urlString = "\(baseURL)/ayah/\(surah):\(ayah)/\(reciterIdentifier)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }

        // Create and execute the request
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            // Handle network errors
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            // Check for data
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.networkError("No data received")))
                }
                return
            }

            // Decode the response
            do {
                let decoder = JSONDecoder()
                let audioResponse = try decoder.decode(AudioVerseResponse.self, from: data)

                // Use primary audio URL
                let audioURLString = audioResponse.data.audio

                guard let audioURL = URL(string: audioURLString) else {
                    DispatchQueue.main.async {
                        completion(.failure(.noAudioAvailable))
                    }
                    return
                }

                // Create cached verse object
                let cachedVerse = CachedAudioVerse(
                    surah: surah,
                    ayah: ayah,
                    audioURL: audioURL,
                    text: audioResponse.data.text
                )

                // Update cache
                self?.addToCache(cachedVerse, key: cacheKey)

                // Return success on main thread
                DispatchQueue.main.async {
                    completion(.success(cachedVerse))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.decodingError(error.localizedDescription)))
                }
            }
        }

        task.resume()
    }

    /// Prefetch the next verse audio while user is practicing
    /// - Parameters:
    ///   - currentSurah: Current surah number
    ///   - currentAyah: Current ayah number
    ///   - totalAyahsInSurah: Total number of ayahs in the current surah
    public func prefetchNextVerse(
        currentSurah: Int,
        currentAyah: Int,
        totalAyahsInSurah: Int
    ) {
        var nextSurah = currentSurah
        var nextAyah = currentAyah + 1

        // Check if we need to move to next surah
        if nextAyah > totalAyahsInSurah {
            nextSurah = currentSurah + 1
            nextAyah = 1

            // Don't prefetch if we're at the last surah (114)
            if nextSurah > 114 {
                return
            }
        }

        // Prefetch in background
        fetchVerseAudio(surah: nextSurah, ayah: nextAyah) { _ in
            // We don't need to handle the result here, just cache it
        }
    }

    /// Clear the audio cache
    public func clearCache() {
        audioCache.removeAll()
    }

    /// Get cached verse if available
    /// - Parameters:
    ///   - surah: Surah number
    ///   - ayah: Ayah number
    /// - Returns: Cached verse or nil if not in cache
    public func getCachedVerse(surah: Int, ayah: Int) -> CachedAudioVerse? {
        let cacheKey = "\(surah):\(ayah)"
        return audioCache[cacheKey]
    }

    /// Check if network is available
    public func isNetworkAvailable() -> Bool {
        return isConnected
    }

    // MARK: - Private Methods

    private func addToCache(_ verse: CachedAudioVerse, key: String) {
        // Add to cache
        audioCache[key] = verse

        // Maintain cache size limit
        if audioCache.count > maxCacheSize {
            // Remove oldest entries
            let sortedKeys = audioCache
                .sorted { $0.value.timestamp < $1.value.timestamp }
                .map { $0.key }

            // Remove oldest entries to maintain size
            let keysToRemove = sortedKeys.prefix(audioCache.count - maxCacheSize)
            for key in keysToRemove {
                audioCache.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Testing Support

    #if DEBUG
    /// For testing: Set network connectivity status
    internal func setNetworkStatus(_ connected: Bool) {
        isConnected = connected
    }

    /// For testing: Get current cache size
    internal var cacheSize: Int {
        return audioCache.count
    }

    /// For testing: Inject cached data directly (respects cache limit)
    internal func injectCachedVerse(_ verse: CachedAudioVerse) {
        let key = "\(verse.surah):\(verse.ayah)"
        addToCache(verse, key: key)
    }
    #endif
}