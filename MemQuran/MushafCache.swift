import Foundation

/// High-performance cache that loads page layouts into memory
public class MushafCache {
    public static let shared = MushafCache()

    // Cache storage
    private var allLines: [Int: [MushafLine]] = [:]  // pageNumber -> lines

    // Loading state
    private var isLoaded = false
    private let loadQueue = DispatchQueue(label: "com.memquran.cache", qos: .userInitiated)

    private init() {
        // Load data asynchronously on initialization
        loadQueue.async {
            Task {
                await self.ensurePagesLoaded(around: 2, range: 5)
                self.isLoaded = true
            }
        }
    }

    // MARK: - Loading

    private func loadAllPageLayouts() async {
        // Load all 604 pages
        for pageNum in 1...604 {
            let lines = await MushafDatabase.shared.getLinesForPage(pageNum)
            allLines[pageNum] = lines
        }
    }

    /// Load only the current page if not in cache (async)
    public func ensureCurrentPageLoaded(_ pageNumber: Int) async {
        guard allLines[pageNumber] == nil else { return }

        let startTime = CFAbsoluteTimeGetCurrent()
        let lines = await MushafDatabase.shared.getLinesForPage(pageNumber)
        allLines[pageNumber] = lines

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("📄 Loaded page \(pageNumber) in \(String(format: "%.2f", elapsed))ms")
    }

    /// Load pages in a sliding window around the current page
    /// Only loads pages that are not already in cache
    public func ensurePagesLoaded(around centerPage: Int, range: Int = 5) async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Calculate the range of pages to load (clamped to valid range)
        let startPage = max(1, centerPage - range)
        let endPage = min(604, centerPage + range)

        var pagesLoaded = 0

        // Load only missing pages
        for pageNum in startPage...endPage {
            if allLines[pageNum] == nil {
                let lines = await MushafDatabase.shared.getLinesForPage(pageNum)
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

    /// Get words for a line (fetched from database)
    public func getWords(from firstId: Int, to lastId: Int) async -> [QuranWord] {
        return await MushafDatabase.shared.getWords(from: firstId, to: lastId)
    }

    /// Get all words for a page organized by line (fetched from database)
    public func getPageWords(_ pageNumber: Int) async -> [Int: [QuranWord]] {
        let tuples = await MushafDatabase.shared.getPageWords(pageNumber)
        var result: [Int: [QuranWord]] = [:]
        for (lineNum, words) in tuples {
            result[lineNum] = words
        }
        return result
    }

    /// Check if cache is ready
    public var isCacheReady: Bool {
        return isLoaded
    }
}
