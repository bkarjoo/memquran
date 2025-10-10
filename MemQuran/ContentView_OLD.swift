import SwiftUI
import SwiftData

extension Notification.Name {
    static let previousPage = Notification.Name("previousPage")
    static let nextPage = Notification.Name("nextPage")
}

struct WordLayout: Codable {
    let lineNumber: Int
    let positionInLine: Int
}

struct Ayah: Codable {
    let text: String
    let numberInSurah: Int
    let page: Int
    let wordLayouts: [WordLayout]?  // Optional: can be provided in JSON or generated automatically
}

struct SurahData: Codable {
    let number: Int
    let name: String
    let englishName: String
    let ayahs: [Ayah]
}

struct Response: Codable {
    let data: SurahData
}

struct PageContentView: View {
    let cachedWordLineData: [ContentView.WordInfo]
    let surah: SurahData?
    let fontFamily: String
    let baseFontSize: CGFloat
    let lineHeight: CGFloat
    let lineSpacing: CGFloat
    let wordSpacing: CGFloat
    let getWordData: (Int, Int, Int) -> WordData?

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 20) {
                if let surah = surah {
                    // Render entire page with 15 fixed lines
                    VStack(alignment: .trailing, spacing: lineSpacing) {
                        ForEach(1...15, id: \.self) { lineNum in
                            let wordsInLine = cachedWordLineData.filter { $0.lineNumber == lineNum }

                            HStack(spacing: wordSpacing) {
                                ForEach(wordsInLine, id: \.id) { wordInfo in
                                    let wordData = getWordData(surah.number, wordInfo.ayahNumber, wordInfo.wordPosition)

                                    Text(wordInfo.text)
                                        .font(.custom(fontFamily, size: baseFontSize))
                                        .opacity(wordData?.isHidden == true ? 0 : 1)
                                        .border(Color.gray.opacity(0.3), width: 1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .frame(height: lineHeight)
                            .border(Color.yellow, width: 1)
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                    }
                    .border(Color.green.opacity(0.5), width: 1)
                    .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @Query private var wordDataRecords: [WordData]
    @State private var surah: SurahData?
    @State private var currentPage: Int = 1
    @State private var cachedWordLineData: [WordInfo] = []
    @State private var showingSettings = false
    @Binding var isTextHidden: Bool

    // Settings from AppStorage
    @AppStorage("fontSize") private var fontSize: Double = 28
    @AppStorage("fontFamily") private var fontFamily: String = "ScheherazadeNew-Regular"

    // Layout constants - all relative to base font size
    var baseFontSize: CGFloat { CGFloat(fontSize) }
    var lineHeight: CGFloat { baseFontSize * 2.2 }  // Line height = 2.2x font size
    var lineSpacing: CGFloat { lineHeight * 0.25 }  // Spacing = 1/4 of line height
    var wordSpacing: CGFloat { baseFontSize * 0.15 } // Word spacing = 15% of font size

    var body: some View {
        VStack(spacing: 0) {
            // Page header
            HStack {
                Button(action: nextPage) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoNext)

                Spacer()

                if let surah = surah {
                    let pageAyahs = surah.ayahs.filter { $0.page == currentPage }
                    Text("\(surah.englishName) - Page \(currentPage) (\(pageAyahs.count) verses)")
                        .font(.headline)
                } else {
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: previousPage) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoPrevious)

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Page content
            PageContentView(
                cachedWordLineData: cachedWordLineData,
                surah: surah,
                fontFamily: fontFamily,
                baseFontSize: baseFontSize,
                lineHeight: lineHeight,
                lineSpacing: lineSpacing,
                wordSpacing: wordSpacing,
                getWordData: getWordData
            )
        }
        .onAppear {
            loadJSON()
        }
        .onChange(of: currentPage) { oldValue, newValue in
            Task {
                await updateCachedWordLineData()
            }
        }
        .onChange(of: isTextHidden) { oldValue, newValue in
            toggleAllWordsHidden(hidden: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .previousPage)) { _ in
            previousPage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextPage)) { _ in
            nextPage()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    var canGoPrevious: Bool {
        guard let surah = surah, let minPage = surah.ayahs.map({ $0.page }).min() else { return false }
        return currentPage > minPage
    }

    var canGoNext: Bool {
        guard let surah = surah, let maxPage = surah.ayahs.map({ $0.page }).max() else { return false }
        return currentPage < maxPage
    }

    func loadJSON() {
        // Load Surah 2 to test pagination (48 pages)
        guard let url = Bundle.main.url(forResource: "surah_2_al-baqarah", withExtension: "json") else {
            let message = "❌ ERROR: Could not find surah_2_al-baqarah.json in bundle"
            print(message)
            writeLog(message)
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let response = try JSONDecoder().decode(Response.self, from: data)
            surah = response.data

            let message = """
            ✅ Loaded: \(response.data.englishName) (\(response.data.name))
               Total ayahs: \(response.data.ayahs.count)
            """
            print(message)
            writeLog(message)

            // Set current page to first page of loaded surah
            if let firstPage = response.data.ayahs.first?.page {
                currentPage = firstPage

                // Count verses on first page
                let pageAyahs = response.data.ayahs.filter { $0.page == firstPage }

                // Count total words on first page
                let totalWords = pageAyahs.reduce(0) { count, ayah in
                    count + ayah.text.split(separator: " ").count
                }

                let pageMessage = "   Starting at page: \(firstPage) with \(pageAyahs.count) verses and \(totalWords) total words (Text views)"
                print(pageMessage)
                writeLog(pageMessage)

                // Initial cache update
                Task {
                    await updateCachedWordLineData()
                }
            }
        } catch {
            let message = "❌ ERROR loading JSON: \(error)"
            print(message)
            writeLog(message)
        }
    }

    func writeLog(_ message: String) {
        let logFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("memquran_debug.log")
        let timestamp = Date()
        let logMessage = "[\(timestamp)] \(message)\n"

        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    func previousPage() {
        guard let surah = surah else { return }
        let pages = Set(surah.ayahs.map { $0.page }).sorted()
        if let currentIndex = pages.firstIndex(of: currentPage), currentIndex > 0 {
            currentPage = pages[currentIndex - 1]
            let pageAyahs = surah.ayahs.filter { $0.page == currentPage }
            let message = "⬅️  Previous page: \(currentPage) (\(pageAyahs.count) verses)"
            print(message)
            writeLog(message)
        }
    }

    func nextPage() {
        guard let surah = surah else { return }
        let pages = Set(surah.ayahs.map { $0.page }).sorted()
        if let currentIndex = pages.firstIndex(of: currentPage), currentIndex < pages.count - 1 {
            currentPage = pages[currentIndex + 1]
            let pageAyahs = surah.ayahs.filter { $0.page == currentPage }
            let message = "➡️  Next page: \(currentPage) (\(pageAyahs.count) verses)"
            print(message)
            writeLog(message)
        }
    }

    func isBookmarked(surah: Int, ayah: Int) -> Bool {
        bookmarks.contains(where: { $0.surahNumber == surah && $0.ayahNumber == ayah })
    }

    func toggleBookmark(surah: Int, ayah: Int) {
        if let bookmark = bookmarks.first(where: { $0.surahNumber == surah && $0.ayahNumber == ayah }) {
            modelContext.delete(bookmark)
        } else {
            let bookmark = Bookmark(surahNumber: surah, ayahNumber: ayah)
            modelContext.insert(bookmark)
        }
    }

    func getWordData(surah: Int, ayah: Int, position: Int) -> WordData? {
        wordDataRecords.first(where: {
            $0.surahNumber == surah && $0.ayahNumber == ayah && $0.wordPosition == position
        })
    }

    func getOrCreateWordData(surah: Int, ayah: Int, position: Int, lineNumber: Int = 0, positionInLine: Int = 0) -> WordData {
        if let existing = getWordData(surah: surah, ayah: ayah, position: position) {
            return existing
        }
        let newWordData = WordData(surahNumber: surah, ayahNumber: ayah, wordPosition: position, lineNumber: lineNumber, positionInLine: positionInLine)
        modelContext.insert(newWordData)
        return newWordData
    }

    struct WordInfo: Hashable, Identifiable {
        let id = UUID()
        let ayahNumber: Int
        let wordPosition: Int
        let text: String
        let lineNumber: Int
        let positionInLine: Int
    }

    func updateCachedWordLineData() async {
        guard let surah = surah else {
            await MainActor.run {
                cachedWordLineData = []
            }
            return
        }

        let pageAyahs = surah.ayahs.filter { $0.page == currentPage }
        let wordData = await generatePageWordLineData(pageAyahs: pageAyahs, surahNumber: surah.number)

        await MainActor.run {
            cachedWordLineData = wordData
        }
    }

    func generatePageWordLineData(pageAyahs: [Ayah], surahNumber: Int) async -> [WordInfo] {
        var result: [WordInfo] = []
        var currentLine = 1
        var currentPosInLine = 1
        let maxWordsPerLine = 10  // Approximate; adjust based on testing

        for ayah in pageAyahs {
            // Strip newlines from text
            let cleanedText = ayah.text.replacingOccurrences(of: "\n", with: "")
            let words = cleanedText.split(separator: " ")

            // Check if ayah has pre-defined word layouts in JSON
            if let wordLayouts = ayah.wordLayouts, wordLayouts.count == words.count {
                // Use provided layout from JSON
                for (index, word) in words.enumerated() {
                    let layout = wordLayouts[index]
                    let wordInfo = WordInfo(
                        ayahNumber: ayah.numberInSurah,
                        wordPosition: index + 1,
                        text: String(word),
                        lineNumber: layout.lineNumber,
                        positionInLine: layout.positionInLine
                    )
                    result.append(wordInfo)

                    // Update WordData with line info
                    let wordData = getOrCreateWordData(
                        surah: surahNumber,
                        ayah: ayah.numberInSurah,
                        position: index + 1,
                        lineNumber: layout.lineNumber,
                        positionInLine: layout.positionInLine
                    )
                    wordData.lineNumber = layout.lineNumber
                    wordData.positionInLine = layout.positionInLine
                }
            } else {
                // Auto-generate layout
                for (index, word) in words.enumerated() {
                    let wordInfo = WordInfo(
                        ayahNumber: ayah.numberInSurah,
                        wordPosition: index + 1,
                        text: String(word),
                        lineNumber: currentLine,
                        positionInLine: currentPosInLine
                    )
                    result.append(wordInfo)

                    // Update WordData with line info
                    let wordData = getOrCreateWordData(
                        surah: surahNumber,
                        ayah: ayah.numberInSurah,
                        position: index + 1,
                        lineNumber: currentLine,
                        positionInLine: currentPosInLine
                    )
                    wordData.lineNumber = currentLine
                    wordData.positionInLine = currentPosInLine

                    currentPosInLine += 1

                    // Move to next line if we exceed max words per line
                    if currentPosInLine > maxWordsPerLine {
                        currentLine += 1
                        currentPosInLine = 1
                    }
                }
            }
        }

        await MainActor.run {
            try? modelContext.save()
        }
        return result
    }

    func toggleAllWordsHidden(hidden: Bool) {
        guard let surah = surah else { return }

        // Only affect words on current page
        let pageAyahs = surah.ayahs.filter { $0.page == currentPage }
        for ayah in pageAyahs {
            let cleanedText = ayah.text.replacingOccurrences(of: "\n", with: "")
            let words = cleanedText.split(separator: " ")
            for (index, _) in words.enumerated() {
                let wordData = getOrCreateWordData(surah: surah.number, ayah: ayah.numberInSurah, position: index + 1)
                wordData.isHidden = hidden
            }
        }

        try? modelContext.save()
    }
}
