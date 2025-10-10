import Foundation

/// High-performance cache that loads all Mushaf data into memory at startup
public class MushafCache {
    public static let shared = MushafCache()

    // Cache storage
    private var allLines: [Int: [MushafLine]] = [:]  // pageNumber -> lines
    private var allWords: [Int: QuranWord] = [:]     // wordId -> word

    // Loading state
    private var isLoaded = false
    private let loadQueue = DispatchQueue(label: "com.memquran.cache", qos: .userInitiated)

    private init() {
        // Load data asynchronously on initialization
        loadQueue.async {
            self.loadAllData()
        }
    }

    // MARK: - Loading

    private func loadAllData() {
        let startTime = CFAbsoluteTimeGetCurrent()

        print("📦 Starting to load Mushaf data into cache...")

        // Load all page layouts (604 pages)
        loadAllPageLayouts()

        // Load all words (~77,800 words)
        loadAllWords()

        isLoaded = true

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("✅ Mushaf cache loaded in \(String(format: "%.3f", elapsed))s")
        print("   - Pages: \(allLines.count)")
        print("   - Words: \(allWords.count)")
    }

    private func loadAllPageLayouts() {
        // Load all 604 pages
        for pageNum in 1...604 {
            let lines = MushafDatabase.shared.getLinesForPage(pageNum)
            allLines[pageNum] = lines
        }
    }

    private func loadAllWords() {
        // Load all words in one query (much faster than individual queries)
        // We'll query for the full range of word IDs
        let words = MushafDatabase.shared.getAllWords()
        for word in words {
            allWords[word.id] = word
        }
    }

    // MARK: - Public API

    /// Get lines for a specific page (instant lookup from cache)
    public func getLinesForPage(_ pageNumber: Int) -> [MushafLine] {
        // Wait for cache to load if needed
        loadQueue.sync {}
        return allLines[pageNumber] ?? []
    }

    /// Get words for a line (instant lookup from cache)
    public func getWords(from firstId: Int, to lastId: Int) -> [QuranWord] {
        // Wait for cache to load if needed
        loadQueue.sync {}

        var result: [QuranWord] = []
        for id in firstId...lastId {
            if let word = allWords[id] {
                result.append(word)
            }
        }
        return result
    }

    /// Get all words for a page organized by line
    public func getPageWords(_ pageNumber: Int) -> [Int: [QuranWord]] {
        let lines = getLinesForPage(pageNumber)
        var result: [Int: [QuranWord]] = [:]

        for line in lines {
            if line.lineType == "ayah",
               let firstId = line.firstWordId,
               let lastId = line.lastWordId {
                let words = getWords(from: firstId, to: lastId)
                result[line.lineNumber] = words
            }
        }

        return result
    }

    /// Check if cache is ready
    public var isCacheReady: Bool {
        return isLoaded
    }
}
