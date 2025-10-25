import Foundation
import Network
import Combine

/// Service for fetching Quran audio from AlQuran.cloud API
public class AudioService: ObservableObject {
    // MARK: - Properties

    private let baseURL = "https://api.alquran.cloud/v1"
    private let session = URLSession.shared
    private var audioCache: [String: CachedAudioVerse] = [:]
    private let maxCacheSize = 10  // Maximum verses to keep in cache (deprecated, using AudioCacheManager now)
    private let networkMonitor = NWPathMonitor()
    private var isConnected = true
    private let cacheManager = AudioCacheManager.shared

    /// Get the current reciter identifier from UserDefaults
    private var reciterIdentifier: String {
        return UserDefaults.standard.string(forKey: "reciterIdentifier") ?? "ar.husary"
    }

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
        // Check disk cache first (optimized - get URL directly without loading Data)
        // AudioCacheManager is an actor, so we need to use Task to await
        Task {
            if let cachedURL = await cacheManager.getCachedAudioURL(reciter: reciterIdentifier, surah: surah, ayah: ayah) {
                print("✅ Cache HIT: \(reciterIdentifier):\(surah):\(ayah) - playing directly from cache")
                // AVPlayer can read directly from cached file - no temp file needed!
                let cachedVerse = CachedAudioVerse(
                    surah: surah,
                    ayah: ayah,
                    audioURL: cachedURL,
                    text: "",  // Text not stored in new cache
                    edition: reciterIdentifier
                )
                DispatchQueue.main.async {
                    completion(.success(cachedVerse))
                }
                return
            }

            print("❌ Cache MISS: \(reciterIdentifier):\(surah):\(ayah) - downloading...")

            // Check network connectivity
            guard isConnected else {
                completion(.failure(.noInternetConnection))
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
            guard let self = self else { return }

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

                // Download the actual audio file
                self.downloadAudioFile(from: audioURL, surah: surah, ayah: ayah, text: audioResponse.data.text, completion: completion)

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.decodingError(error.localizedDescription)))
                }
            }
            }

            task.resume()
        }
    }

    /// Download the actual audio file and cache it
    private func downloadAudioFile(
        from url: URL,
        surah: Int,
        ayah: Int,
        text: String,
        completion: @escaping (Result<CachedAudioVerse, AudioServiceError>) -> Void
    ) {
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            guard let audioData = data else {
                DispatchQueue.main.async {
                    completion(.failure(.networkError("No audio data received")))
                }
                return
            }

            print("📥 Downloaded \(audioData.count / 1024) KB for \(self.reciterIdentifier):\(surah):\(ayah)")

            // Cache the audio data and get URL for playback (actor method, use Task)
            Task {
                // Cache the data
                await self.cacheManager.cacheAudio(data: audioData, reciter: self.reciterIdentifier, surah: surah, ayah: ayah)

                // Try to get the cached file URL (avoids creating temp file)
                if let cachedURL = await self.cacheManager.getCachedAudioURL(reciter: self.reciterIdentifier, surah: surah, ayah: ayah) {
                    let cachedVerse = CachedAudioVerse(
                        surah: surah,
                        ayah: ayah,
                        audioURL: cachedURL,
                        text: text,
                        edition: self.reciterIdentifier
                    )

                    DispatchQueue.main.async {
                        completion(.success(cachedVerse))
                    }
                } else {
                    // Fallback: create temp file if cached URL unavailable for any reason
                    if let tempURL = self.writeTempFile(data: audioData, surah: surah, ayah: ayah) {
                        let cachedVerse = CachedAudioVerse(
                            surah: surah,
                            ayah: ayah,
                            audioURL: tempURL,
                            text: text,
                            edition: self.reciterIdentifier
                        )

                        DispatchQueue.main.async {
                            completion(.success(cachedVerse))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(.networkError("Failed to create playback URL")))
                        }
                    }
                }
            }
        }

        task.resume()
    }

    /// Write audio data to temporary file for AVPlayer
    private func writeTempFile(data: Data, surah: Int, ayah: Int) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "\(reciterIdentifier)_\(surah)_\(ayah).mp3"
        let tempURL = tempDir.appendingPathComponent(filename)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("❌ Failed to write temp file: \(error)")
            return nil
        }
    }

    /// Prefetch verses to maintain lookahead buffer
    /// - Parameters:
    ///   - currentSurah: Current surah number
    ///   - currentAyah: Current ayah number
    public func prefetchLookahead(currentSurah: Int, currentAyah: Int) {
        // Get list of verses that need to be prefetched (actor method, use Task)
        Task {
            let versesToFetch = await cacheManager.getVersesToPrefetch(
                reciter: reciterIdentifier,
                surah: currentSurah,
                ayah: currentAyah
            )

            guard !versesToFetch.isEmpty else {
                print("✅ Lookahead buffer is full, no prefetch needed")
                return
            }

            print("📥 Prefetching \(versesToFetch.count) verses to maintain 10 MB lookahead...")

            // Download verses in background
            for (surah, ayah) in versesToFetch {
                fetchVerseAudio(surah: surah, ayah: ayah) { result in
                    switch result {
                    case .success:
                        print("✅ Prefetched: \(surah):\(ayah)")
                    case .failure(let error):
                        print("⚠️ Failed to prefetch \(surah):\(ayah): \(error)")
                    }
                }
            }
        }
    }

    /// Legacy method for backwards compatibility (deprecated)
    @available(*, deprecated, message: "Use prefetchLookahead instead")
    public func prefetchNextVerse(
        currentSurah: Int,
        currentAyah: Int,
        totalAyahsInSurah: Int
    ) {
        prefetchLookahead(currentSurah: currentSurah, currentAyah: currentAyah)
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
        let cacheKey = "\(reciterIdentifier):\(surah):\(ayah)"
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