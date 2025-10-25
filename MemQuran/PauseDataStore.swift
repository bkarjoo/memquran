import Foundation

/// Persistent storage manager for verse pause detection data
/// Stores pause data separately from audio cache to survive cache clearing
/// Uses actor isolation to perform I/O off the main thread
actor PauseDataStore {

    // MARK: - Properties

    /// Shared singleton instance
    static let shared = PauseDataStore()

    /// Directory where pause data JSON files are stored
    private let pauseDataDirectory: URL

    /// In-memory cache of loaded pause data for faster access
    private var memoryCache: [String: VersePauseData] = [:]

    // MARK: - Initialization

    private init() {
        // Create pause data directory in Documents folder
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.pauseDataDirectory = documentsDirectory.appendingPathComponent("PauseData", isDirectory: true)

        // Ensure the directory exists (synchronous initialization is ok)
        Task {
            await createDirectoryIfNeeded()
        }
    }

    // MARK: - Public Methods

    /// Retrieve pause data for a specific verse and reciter
    /// - Parameters:
    ///   - edition: Reciter edition identifier (e.g., "ar.alafasy")
    ///   - surah: Surah number (1-114)
    ///   - ayah: Ayah number within the surah
    /// - Returns: VersePauseData if found, nil otherwise
    func getPauseData(edition: String, surah: Int, ayah: Int) async -> VersePauseData? {
        let key = makeKey(edition: edition, surah: surah, ayah: ayah)

        // Check memory cache first
        if let cached = memoryCache[key] {
            return cached
        }

        // Load from disk (off main thread)
        let fileURL = fileURL(for: edition, surah: surah, ayah: ayah)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let pauseData = try JSONDecoder().decode(VersePauseData.self, from: data)

            // Cache in memory for future access
            memoryCache[key] = pauseData

            return pauseData
        } catch {
            print("Error loading pause data from \(fileURL.path): \(error)")
            return nil
        }
    }

    /// Store pause data after analysis
    /// - Parameter data: The VersePauseData to persist
    func savePauseData(_ data: VersePauseData) async {
        let key = data.key
        let fileURL = fileURL(for: data.edition, surah: data.surah, ayah: data.ayah)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(data)

            // Ensure directory exists before writing
            await createDirectoryIfNeeded()

            // Write to disk (off main thread)
            try jsonData.write(to: fileURL, options: .atomic)

            // Update memory cache
            memoryCache[key] = data

            print("Saved pause data: \(key) with \(data.pauses.count) pauses")
        } catch {
            print("Error saving pause data to \(fileURL.path): \(error)")
        }
    }

    /// Check if pause data exists without loading it
    /// - Parameters:
    ///   - edition: Reciter edition identifier
    ///   - surah: Surah number
    ///   - ayah: Ayah number
    /// - Returns: true if pause data file exists, false otherwise
    func hasPauseData(edition: String, surah: Int, ayah: Int) -> Bool {
        let fileURL = fileURL(for: edition, surah: surah, ayah: ayah)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Clear pause data older than specified detection version
    /// Useful when algorithm improves and we want to re-analyze
    /// - Parameter version: Minimum version to keep (older versions are deleted)
    func clearPauseData(olderThan version: Int) async {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: pauseDataDirectory, includingPropertiesForKeys: nil)

            var deletedCount = 0

            for fileURL in files {
                guard fileURL.pathExtension == "json" else { continue }

                // Load the file to check version
                if let data = try? Data(contentsOf: fileURL),
                   let pauseData = try? JSONDecoder().decode(VersePauseData.self, from: data) {

                    if pauseData.detectionVersion < version {
                        try fileManager.removeItem(at: fileURL)

                        // Remove from memory cache
                        memoryCache.removeValue(forKey: pauseData.key)

                        deletedCount += 1
                    }
                }
            }

            print("Cleared \(deletedCount) pause data files older than version \(version)")
        } catch {
            print("Error clearing old pause data: \(error)")
        }
    }

    /// Delete all pause data (for testing or reset)
    func clearAllPauseData() async {
        do {
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: pauseDataDirectory.path) {
                try fileManager.removeItem(at: pauseDataDirectory)
                await createDirectoryIfNeeded()
            }

            memoryCache.removeAll()

            print("Cleared all pause data")
        } catch {
            print("Error clearing all pause data: \(error)")
        }
    }

    /// Get count of stored pause data files (for debugging/stats)
    func getStoredCount() async -> Int {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: pauseDataDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "json" }.count
        } catch {
            return 0
        }
    }

    // MARK: - Private Helper Methods

    /// Create the pause data directory if it doesn't exist
    private func createDirectoryIfNeeded() async {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: pauseDataDirectory.path) {
            do {
                try fileManager.createDirectory(at: pauseDataDirectory, withIntermediateDirectories: true)
                print("Created pause data directory at: \(pauseDataDirectory.path)")
            } catch {
                print("Error creating pause data directory: \(error)")
            }
        }
    }

    /// Generate a unique key for a verse and reciter combination
    private func makeKey(edition: String, surah: Int, ayah: Int) -> String {
        return "\(edition):\(surah):\(ayah)"
    }

    /// Generate the file URL for a specific pause data file
    /// File naming: {edition}_{surah}_{ayah}.json
    private func fileURL(for edition: String, surah: Int, ayah: Int) -> URL {
        let filename = "\(edition)_\(surah)_\(ayah).json"
        return pauseDataDirectory.appendingPathComponent(filename)
    }
}
