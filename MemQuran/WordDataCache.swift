import Foundation
import SwiftData
import Combine

/// Sliding window cache for WordData - keeps current page ± 5 pages in memory
@MainActor
class WordDataCache: ObservableObject {
    private var cache: [String: WordData] = [:]  // "surah:ayah:position" -> WordData
    private var currentWindow: (start: Int, end: Int) = (0, 0)
    private let windowSize = 5  // ± 5 pages

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Load WordData for only the current page (synchronous, fast)
    func preloadCurrentPage(_ pageNumber: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Get all words for just this page
        let pageWords = MushafCache.shared.getPageWords(pageNumber)
        var wordsLoaded = 0

        for (_, words) in pageWords {
            for word in words {
                let key = makeKey(surah: word.surah, ayah: word.ayah, position: word.word)

                // Skip if already in cache
                if cache[key] != nil {
                    continue
                }

                // Extract values for predicate
                let surah = word.surah
                let ayah = word.ayah
                let position = word.word

                // Try to fetch existing WordData
                let descriptor = FetchDescriptor<WordData>(
                    predicate: #Predicate<WordData> { wordData in
                        wordData.surahNumber == surah &&
                        wordData.ayahNumber == ayah &&
                        wordData.wordPosition == position
                    }
                )

                if let existing = try? modelContext.fetch(descriptor).first {
                    cache[key] = existing
                } else {
                    // Create new WordData
                    let newWordData = WordData(
                        surahNumber: word.surah,
                        ayahNumber: word.ayah,
                        wordPosition: word.word
                    )
                    modelContext.insert(newWordData)
                    cache[key] = newWordData
                }
                wordsLoaded += 1
            }
        }

        // Save all new WordData at once
        if wordsLoaded > 0 {
            try? modelContext.save()
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("📦 Preloaded page \(pageNumber) (\(wordsLoaded) words) in \(String(format: "%.2f", elapsed))ms")
        }
    }

    /// Load WordData for a sliding window of pages around the current page
    func preloadPages(around currentPage: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()

        let startPage = max(1, currentPage - windowSize)
        let endPage = min(604, currentPage + windowSize)

        // If we're already loaded for this window, skip
        if currentWindow.start == startPage && currentWindow.end == endPage {
            return
        }

        // Clear old cache
        cache.removeAll()
        currentWindow = (startPage, endPage)

        // Get all words for the page range
        var allWords: [(surah: Int, ayah: Int, position: Int)] = []
        for page in startPage...endPage {
            let pageWords = MushafCache.shared.getPageWords(page)
            for (_, words) in pageWords {
                for word in words {
                    allWords.append((word.surah, word.ayah, word.word))
                }
            }
        }

        // Fetch or create WordData for all words in the window
        for (surah, ayah, position) in allWords {
            let key = makeKey(surah: surah, ayah: ayah, position: position)

            // Try to fetch existing WordData
            let descriptor = FetchDescriptor<WordData>(
                predicate: #Predicate<WordData> { word in
                    word.surahNumber == surah &&
                    word.ayahNumber == ayah &&
                    word.wordPosition == position
                }
            )

            if let existing = try? modelContext.fetch(descriptor).first {
                cache[key] = existing
            } else {
                // Create new WordData
                let newWordData = WordData(
                    surahNumber: surah,
                    ayahNumber: ayah,
                    wordPosition: position
                )
                modelContext.insert(newWordData)
                cache[key] = newWordData
            }
        }

        // Save all new WordData at once
        try? modelContext.save()

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("📦 Preloaded pages \(startPage)-\(endPage) (\(cache.count) words) in \(String(format: "%.2f", elapsed))ms")
    }

    /// Get WordData from cache (instant lookup)
    func getWordData(surah: Int, ayah: Int, position: Int) -> WordData? {
        let key = makeKey(surah: surah, ayah: ayah, position: position)
        return cache[key]
    }

    /// Update a WordData property and ensure it's saved
    func updateWordData(surah: Int, ayah: Int, position: Int, update: (WordData) -> Void) {
        guard let wordData = getWordData(surah: surah, ayah: ayah, position: position) else {
            return
        }
        update(wordData)
        try? modelContext.save()
    }

    /// Toggle hide state for all words on a page
    func toggleAllWordsHidden(on page: Int, hidden: Bool) {
        let pageWords = MushafCache.shared.getPageWords(page)
        for (_, words) in pageWords {
            for word in words {
                updateWordData(surah: word.surah, ayah: word.ayah, position: word.word) { wordData in
                    wordData.isHidden = hidden
                }
            }
        }
    }

    private func makeKey(surah: Int, ayah: Int, position: Int) -> String {
        return "\(surah):\(ayah):\(position)"
    }
}
