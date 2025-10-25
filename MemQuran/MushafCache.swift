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
            // Start with a default page (page 2) and load surrounding pages
            self.loadAllWords()  // Words are small, keep them all loaded
            self.ensurePagesLoaded(around: 2, range: 5)
            self.isLoaded = true
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

    /// Load only the current page if not in cache (synchronous, fast)
    public func ensureCurrentPageLoaded(_ pageNumber: Int) {
        guard allLines[pageNumber] == nil else { return }

        let startTime = CFAbsoluteTimeGetCurrent()
        let lines = MushafDatabase.shared.getLinesForPage(pageNumber)
        allLines[pageNumber] = lines

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("📄 Loaded page \(pageNumber) in \(String(format: "%.2f", elapsed))ms")
    }

    /// Load pages in a sliding window around the current page
    /// Only loads pages that are not already in cache
    public func ensurePagesLoaded(around centerPage: Int, range: Int = 5) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Calculate the range of pages to load (clamped to valid range)
        let startPage = max(1, centerPage - range)
        let endPage = min(604, centerPage + range)

        var pagesLoaded = 0

        // Load only missing pages
        for pageNum in startPage...endPage {
            if allLines[pageNum] == nil {
                let lines = MushafDatabase.shared.getLinesForPage(pageNum)
                allLines[pageNum] = lines
                pagesLoaded += 1
            }
        }

        if pagesLoaded > 0 {
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("📄 Loaded \(pagesLoaded) pages around page \(centerPage) in \(String(format: "%.2f", elapsed))ms")
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
