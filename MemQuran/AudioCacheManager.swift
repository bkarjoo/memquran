import Foundation

/// Manages persistent disk-based caching of Quran verse audio files
/// with size-based LRU eviction and intelligent prefetching
public actor AudioCacheManager {

    // MARK: - CACHING POLICY

    /*
     ┌─────────────────────────────────────────────────────────────────┐
     │                        CACHING POLICY                           │
     └─────────────────────────────────────────────────────────────────┘

     MAX CACHE SIZE: 300 MB
     - Hard limit for total cached audio data on disk

     EVICTION STRATEGY:
     - When cache exceeds 300 MB, remove oldest 25 MB of data
     - Uses LRU (Least Recently Used) algorithm
     - Eviction based on last access timestamp

     PERSISTENCE:
     - Disk storage in app's Caches directory
     - Survives app restarts and device reboots
     - Does NOT sync to iCloud or other devices

     INDEX KEY FORMAT:
     - "reciter:surah:ayah" (e.g., "ar.husary:2:255")
     - Allows multiple reciters to be cached independently

     LOOKAHEAD PREFETCHING:
     - Target buffer: 10 MB of verses ahead of current position
     - Refill trigger: When forward cache drops below 5 MB
     - Refill amount: Download +5 MB worth of verses (back to 10 MB)
     - Direction: Sequential verse order (crosses surah boundaries)
     - Hard limit: Stops at end of Quran (114:6)
     - Timing: Prefetch during practice pause (user idle time)

     CACHE BEHAVIOR:
     - Cache Hit: Play instantly from disk (no network)
     - Cache Miss: Download → Cache → Play
     - No assumptions about user navigation patterns
     - Only prefetches forward (next verses in sequence)
     */

    // MARK: - Constants

    private let maxCacheSize: Int64 = 300 * 1024 * 1024  // 300 MB
    private let evictionSize: Int64 = 25 * 1024 * 1024   // 25 MB
    private let lookaheadTarget: Int64 = 10 * 1024 * 1024  // 10 MB
    private let lookaheadRefillTrigger: Int64 = 5 * 1024 * 1024  // 5 MB

    // End of Quran
    private let finalSurah = 114
    private let finalAyah = 6

    // MARK: - Properties

    private let cacheDirectory: URL
    private let metadataFile: URL
    private var metadata: [String: CacheMetadata] = [:]
    private let fileManager = FileManager.default
    // Note: Actor isolation protects metadata and all mutable state

    // MARK: - Singleton

    public static let shared = AudioCacheManager()

    // MARK: - Initialization

    private init() {
        // Setup cache directory in app's Caches folder
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent("QuranAudioCache", isDirectory: true)
        metadataFile = cacheDirectory.appendingPathComponent("metadata.json")

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load metadata and verify cache asynchronously
        // Init is nonisolated, so we use Task for actor-isolated methods
        Task {
            await loadMetadata()
            await verifyCache()
        }
    }

    // MARK: - Public Methods

    /// Get cached audio data for a verse
    /// - Parameters:
    ///   - reciter: Reciter identifier
    ///   - surah: Surah number (1-114)
    ///   - ayah: Ayah number
    /// - Returns: Cached audio data if available, nil otherwise
    public func getCachedAudio(reciter: String, surah: Int, ayah: Int) async -> Data? {
        let key = cacheKey(reciter: reciter, surah: surah, ayah: ayah)

        // Actor isolation protects metadata access
        guard let meta = metadata[key] else {
            return nil
        }

        let fileURL = cacheDirectory.appendingPathComponent(meta.filename)

        // Disk I/O - this is why the method is async
        guard let data = try? Data(contentsOf: fileURL) else {
            // File missing - remove from metadata
            removeFromMetadata(key: key)
            return nil
        }

        // Update last accessed time
        updateAccessTime(key: key)

        return data
    }

    /// Cache audio data for a verse
    /// - Parameters:
    ///   - data: Audio file data
    ///   - reciter: Reciter identifier
    ///   - surah: Surah number (1-114)
    ///   - ayah: Ayah number
    public func cacheAudio(data: Data, reciter: String, surah: Int, ayah: Int) async {
        let key = cacheKey(reciter: reciter, surah: surah, ayah: ayah)
        let filename = "\(key).mp3"
        let fileURL = cacheDirectory.appendingPathComponent(filename)

        // Write audio data to disk - this is why the method is async
        do {
            try data.write(to: fileURL)

            // Add to metadata - actor isolation protects this
            let meta = CacheMetadata(
                key: key,
                filename: filename,
                reciter: reciter,
                surah: surah,
                ayah: ayah,
                size: Int64(data.count),
                lastAccessed: Date()
            )

            metadata[key] = meta
            saveMetadata()

            // Check cache size and evict if needed
            evictIfNeeded()

        } catch {
            print("❌ Failed to cache audio: \(error)")
        }
    }

    /// Calculate size of cached verses ahead of current position
    /// - Parameters:
    ///   - reciter: Current reciter
    ///   - surah: Current surah
    ///   - ayah: Current ayah
    /// - Returns: Total size in bytes of cached verses ahead
    public func getLookaheadSize(reciter: String, surah: Int, ayah: Int) async -> Int64 {
        // Actor isolation protects metadata access
        var totalSize: Int64 = 0
        var currentSurah = surah
        var currentAyah = ayah + 1  // Start from next verse

        // Iterate through verses until we reach the end of Quran or find a gap
        while !(currentSurah == finalSurah && currentAyah > finalAyah) {
            let key = cacheKey(reciter: reciter, surah: currentSurah, ayah: currentAyah)

            if let meta = metadata[key] {
                totalSize += meta.size
            } else {
                // No more consecutive cached verses - gap found
                break
            }

            // Move to next verse, crossing surah boundaries
            let (nextSurah, nextAyah) = await getNextVerse(surah: currentSurah, ayah: currentAyah)
            if nextSurah == 0 {
                // End of Quran reached
                break
            }
            currentSurah = nextSurah
            currentAyah = nextAyah
        }

        return totalSize
    }

    /// Check if lookahead buffer needs refilling
    /// - Parameters:
    ///   - reciter: Current reciter
    ///   - surah: Current surah
    ///   - ayah: Current ayah
    /// - Returns: True if lookahead is below refill trigger
    public func needsLookaheadRefill(reciter: String, surah: Int, ayah: Int) async -> Bool {
        let lookaheadSize = await getLookaheadSize(reciter: reciter, surah: surah, ayah: ayah)
        return lookaheadSize < lookaheadRefillTrigger
    }

    /// Get current total cache size
    /// - Returns: Total size in bytes
    public func getTotalCacheSize() -> Int64 {
        // Actor isolation protects metadata access
        return metadata.values.reduce(0) { $0 + $1.size }
    }

    /// Get list of verses to prefetch to reach lookahead target
    /// - Parameters:
    ///   - reciter: Current reciter
    ///   - surah: Current surah
    ///   - ayah: Current ayah
    /// - Returns: Array of (surah, ayah) tuples to download
    public func getVersesToPrefetch(reciter: String, surah: Int, ayah: Int) async -> [(surah: Int, ayah: Int)] {
        let currentLookahead = await getLookaheadSize(reciter: reciter, surah: surah, ayah: ayah)

        // If we're above the refill trigger, no need to prefetch
        if currentLookahead >= lookaheadRefillTrigger {
            return []
        }

        // Actor isolation protects metadata access
        var versesToFetch: [(surah: Int, ayah: Int)] = []
        var estimatedSize: Int64 = currentLookahead
        var currentSurah = surah
        var currentAyah = ayah + 1

        // Iterate through verses until we reach target size or end of Quran
        while estimatedSize < lookaheadTarget && !(currentSurah == finalSurah && currentAyah > finalAyah) {
            let key = cacheKey(reciter: reciter, surah: currentSurah, ayah: currentAyah)

            // Only add if not already cached
            if metadata[key] == nil {
                versesToFetch.append((surah: currentSurah, ayah: currentAyah))
                // Estimate average verse size at 75 KB
                estimatedSize += 75 * 1024
            }

            // Move to next verse
            let (nextSurah, nextAyah) = await getNextVerse(surah: currentSurah, ayah: currentAyah)
            if nextSurah == 0 {
                // End of Quran reached
                break
            }
            currentSurah = nextSurah
            currentAyah = nextAyah
        }

        return versesToFetch
    }

    /// Clear all cached audio (for testing or user request)
    public func clearCache() async {
        // Actor isolation protects metadata mutations
        // Remove all files - disk I/O is why this is async
        for meta in metadata.values {
            let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
            try? fileManager.removeItem(at: fileURL)
        }

        // Clear metadata
        metadata.removeAll()
        saveMetadata()
    }

    // MARK: - Private Methods

    /// Get the next verse in sequence, handling surah boundaries
    /// - Parameters:
    ///   - surah: Current surah
    ///   - ayah: Current ayah
    /// - Returns: Next (surah, ayah), or (0, 0) if end of Quran
    private func getNextVerse(surah: Int, ayah: Int) async -> (surah: Int, ayah: Int) {
        // Check if we're at the end of Quran
        if surah == finalSurah && ayah >= finalAyah {
            return (0, 0)
        }

        // SurahInfo.getVerseCount touches SQLite; keep it on main thread for safety
        let verseCount = await MainActor.run {
            SurahInfo.getVerseCount(for: surah)
        }

        if ayah < verseCount {
            // More verses in current surah
            return (surah, ayah + 1)
        } else {
            // Move to next surah
            if surah < finalSurah {
                return (surah + 1, 1)
            } else {
                // End of Quran
                return (0, 0)
            }
        }
    }

    nonisolated private func cacheKey(reciter: String, surah: Int, ayah: Int) -> String {
        return "\(reciter):\(surah):\(ayah)"
    }

    private func updateAccessTime(key: String) {
        // Actor isolation protects metadata mutation
        metadata[key]?.lastAccessed = Date()
        saveMetadata()
    }

    private func removeFromMetadata(key: String) {
        // Actor isolation protects metadata mutation
        metadata.removeValue(forKey: key)
        saveMetadata()
    }

    private func evictIfNeeded() {
        // Actor isolation protects metadata access and mutations
        let totalSize = metadata.values.reduce(0) { $0 + $1.size }

        if totalSize > maxCacheSize {
            print("🗑️ Cache size \(totalSize / 1024 / 1024) MB exceeds limit, evicting oldest 25 MB")
            evictOldest(targetSize: evictionSize)
        }
    }

    private func evictOldest(targetSize: Int64) {
        // Sort by last accessed (oldest first)
        let sortedEntries = metadata.values.sorted { $0.lastAccessed < $1.lastAccessed }

        var freedSize: Int64 = 0

        for meta in sortedEntries {
            if freedSize >= targetSize {
                break
            }

            // Delete file
            let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
            try? fileManager.removeItem(at: fileURL)

            // Remove from metadata
            metadata.removeValue(forKey: meta.key)

            freedSize += meta.size

            print("🗑️ Evicted: \(meta.key) (\(meta.size / 1024) KB)")
        }

        saveMetadata()

        print("✅ Freed \(freedSize / 1024 / 1024) MB from cache")
    }

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataFile) else {
            print("ℹ️ No existing metadata found, starting fresh")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadataArray = try decoder.decode([CacheMetadata].self, from: data)

            metadata = Dictionary(uniqueKeysWithValues: metadataArray.map { ($0.key, $0) })

            print("✅ Loaded \(metadata.count) cached verses, total size: \(getTotalCacheSize() / 1024 / 1024) MB")
        } catch {
            print("❌ Failed to load metadata: \(error)")
        }
    }

    private func saveMetadata() {
        // Actor-isolated: safe to access metadata and write to disk
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let metadataArray = Array(metadata.values)
            let data = try encoder.encode(metadataArray)

            try data.write(to: metadataFile)
        } catch {
            print("❌ Failed to save metadata: \(error)")
        }
    }

    private func verifyCache() {
        // Actor isolation protects metadata access and mutations
        var keysToRemove: [String] = []

        for (key, meta) in metadata {
            let fileURL = cacheDirectory.appendingPathComponent(meta.filename)

            if !fileManager.fileExists(atPath: fileURL.path) {
                print("⚠️ Cache file missing: \(key), removing from metadata")
                keysToRemove.append(key)
            }
        }

        for key in keysToRemove {
            metadata.removeValue(forKey: key)
        }

        if !keysToRemove.isEmpty {
            saveMetadata()
            print("✅ Verified cache, removed \(keysToRemove.count) stale entries")
        }
    }
}

// MARK: - Cache Metadata Model

struct CacheMetadata: Codable, Sendable {
    let key: String
    let filename: String
    let reciter: String
    let surah: Int
    let ayah: Int
    let size: Int64
    var lastAccessed: Date
}
