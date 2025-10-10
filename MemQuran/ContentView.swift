import SwiftUI
import SwiftData

extension Notification.Name {
    static let previousPage = Notification.Name("previousPage")
    static let nextPage = Notification.Name("nextPage")
}

// PreferenceKey to collect word widths from each line
struct WordWidthsKey: PreferenceKey {
    static var defaultValue: [Int: [CGFloat]] = [:] // lineNumber -> [widths]

    static func reduce(value: inout [Int: [CGFloat]], nextValue: () -> [Int: [CGFloat]]) {
        value.merge(nextValue()) { $1 }
    }
}

// Word identifier for selection
struct WordIdentifier: Equatable, Hashable {
    let surah: Int
    let ayah: Int
    let position: Int
}

struct PageContentView: View {
    let lines: [MushafLine]
    let lineWords: [Int: [QuranWord]]  // lineNumber -> words
    let fontFamily: String
    let baseFontSize: CGFloat
    let lineHeight: CGFloat
    let lineSpacing: CGFloat
    let wordSpacing: CGFloat
    let getWordData: (Int, Int, Int) -> WordData?
    @Binding var selectedWord: WordIdentifier?
    let onWordTap: (WordIdentifier) -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .trailing, spacing: 0) {
                    // Render all 15 lines
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...15, id: \.self) { lineNum in
                            let lineInfo = lines.first(where: { $0.lineNumber == lineNum })
                            let wordsInLine = lineWords[lineNum] ?? []

                            JustifiedLineView(
                                lineNumber: lineNum,
                                lineInfo: lineInfo,
                                words: wordsInLine,
                                fontFamily: fontFamily,
                                baseFontSize: baseFontSize,
                                lineHeight: lineHeight,
                                containerWidth: geometry.size.width,
                                getWordData: getWordData,
                                selectedWord: $selectedWord,
                                onWordTap: onWordTap
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                // .padding()
            }
        }
    }
}

// Preference key to read actual container width per line
struct LineWidthKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// Preference key to read word widths within a line
struct WordWidthKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// Individual justified line view
struct JustifiedLineView: View {
    let lineNumber: Int
    let lineInfo: MushafLine?
    let words: [QuranWord]
    let fontFamily: String
    let baseFontSize: CGFloat
    let lineHeight: CGFloat
    let containerWidth: CGFloat  // Not used anymore, keeping for compatibility
    let getWordData: (Int, Int, Int) -> WordData?
    @Binding var selectedWord: WordIdentifier?
    let onWordTap: (WordIdentifier) -> Void

    @State private var measuredWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if lineInfo?.lineType == "surah_name" {
                    // TODO: Display surah name
                    Text("Surah Name")
                        .font(.custom(fontFamily, size: baseFontSize))
                } else if lineInfo?.lineType == "basmallah" {
                    Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ")
                        .font(.custom(fontFamily, size: baseFontSize))
                } else {
                    let positions = calculateWordPositions(containerWidth: geo.size.width)

                    ForEach(Array(words.enumerated()), id: \.element.id) { index, quranWord in
                        let wordData = getWordData(quranWord.surah, quranWord.ayah, quranWord.word)
                        let wordId = WordIdentifier(surah: quranWord.surah, ayah: quranWord.ayah, position: quranWord.word)
                        let isSelected = selectedWord == wordId

                        Text(quranWord.text)
                            .font(.custom(fontFamily, size: baseFontSize))
                            .opacity(wordData?.isHidden == true ? 0 : 1)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.blue, lineWidth: isSelected ? 2 : 0)
                            )
                            .position(x: positions[index] ?? 0, y: lineHeight / 2)
                            .onTapGesture {
                                onWordTap(wordId)
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: lineInfo?.isCentered == true ? .center : .trailing)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .frame(height: lineHeight)
    }

    private func calculateWordWidths() -> [CGFloat] {
        let font = NSFont(name: fontFamily, size: baseFontSize) ?? NSFont.systemFont(ofSize: baseFontSize)
        var wordWidths: [CGFloat] = []

        for word in words {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = (word.text as NSString).size(withAttributes: attributes)
            wordWidths.append(size.width)
        }

        return wordWidths
    }

    private func calculateWordPositions(containerWidth: CGFloat) -> [Int: CGFloat] {
        guard words.count > 0, containerWidth > 0 else {
            return [:]
        }

        // Calculate text widths using NSAttributedString
        let wordWidths = calculateWordWidths()
        let totalTextWidth = wordWidths.reduce(0, +)

        // Calculate spacing between words
        let gaps = CGFloat(words.count - 1)
        let spacing = gaps > 0 ? max(0, (containerWidth - totalTextWidth) / gaps) : 0

        // Calculate x-position for each word (RTL, so first word on right, last word on left)
        var positions: [Int: CGFloat] = [:]
        var currentX = containerWidth

        for (index, width) in wordWidths.enumerated().reversed() {
            currentX -= width / 2  // Center of word
            positions[index] = currentX
            currentX -= width / 2  // Other half of word
            currentX -= spacing  // Space to next word
        }

        return positions
    }
}

// Helper preference key for collecting sizes
struct SizePreference: Equatable {
    let index: Int
    let width: CGFloat
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: [SizePreference] = []

    static func reduce(value: inout [SizePreference], nextValue: () -> [SizePreference]) {
        value.append(contentsOf: nextValue())
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @StateObject private var wordDataCache: WordDataCache
    @State private var currentPage: Int = 2  // Start at page 2 (Al-Baqarah)
    @State private var lines: [MushafLine] = []
    @State private var lineWords: [Int: [QuranWord]] = [:]
    @State private var showingSettings = false
    @State private var selectedWord: WordIdentifier?
    @Binding var isTextHidden: Bool

    init(isTextHidden: Binding<Bool>, modelContext: ModelContext) {
        self._isTextHidden = isTextHidden
        self._wordDataCache = StateObject(wrappedValue: WordDataCache(modelContext: modelContext))
    }

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
                .disabled(currentPage >= 604)

                Spacer()

                Text("Page \(currentPage) of 604")
                    .font(.headline)

                Spacer()

                Button(action: previousPage) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage <= 1)

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)

                // Word navigation buttons
                Button(action: nextWord) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                .disabled(selectedWord == nil || !canMoveToNextWord())

                Button(action: previousWord) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
                .disabled(selectedWord == nil || !canMoveToPreviousWord())

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Page content
            PageContentView(
                lines: lines,
                lineWords: lineWords,
                fontFamily: fontFamily,
                baseFontSize: baseFontSize,
                lineHeight: lineHeight,
                lineSpacing: lineSpacing,
                wordSpacing: wordSpacing,
                getWordData: getWordData,
                selectedWord: $selectedWord,
                onWordTap: handleWordTap
            )
        }
        .onAppear {
            loadPage(currentPage)
        }
        .onChange(of: currentPage) { oldValue, newValue in
            loadPage(newValue)
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

    func loadPage(_ pageNumber: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Clear selection when changing pages
        selectedWord = nil

        // Preload WordData cache for sliding window
        wordDataCache.preloadPages(around: pageNumber)

        // Get lines and words from cache (instant lookup)
        lines = MushafCache.shared.getLinesForPage(pageNumber)
        lineWords = MushafCache.shared.getPageWords(pageNumber)

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        writeLog("📄 Loaded page \(pageNumber) in \(String(format: "%.2f", elapsed))ms")
    }

    func handleWordTap(_ wordId: WordIdentifier) {
        // Toggle selection: if already selected, deselect; otherwise select
        if selectedWord == wordId {
            selectedWord = nil
        } else {
            selectedWord = wordId
        }
        writeLog("🔘 Word tapped: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
    }

    // Get all words on current page in order
    func getAllWordsInOrder() -> [WordIdentifier] {
        var allWords: [WordIdentifier] = []

        // Sort line numbers and iterate through them
        let sortedLineNumbers = lineWords.keys.sorted()
        for lineNum in sortedLineNumbers {
            if let words = lineWords[lineNum] {
                for word in words {
                    allWords.append(WordIdentifier(surah: word.surah, ayah: word.ayah, position: word.word))
                }
            }
        }

        return allWords
    }

    func canMoveToPreviousWord() -> Bool {
        guard let current = selectedWord else { return false }
        let allWords = getAllWordsInOrder()
        guard let currentIndex = allWords.firstIndex(of: current) else { return false }
        return currentIndex > 0
    }

    func canMoveToNextWord() -> Bool {
        guard let current = selectedWord else { return false }
        let allWords = getAllWordsInOrder()
        guard let currentIndex = allWords.firstIndex(of: current) else { return false }
        return currentIndex < allWords.count - 1
    }

    func previousWord() {
        guard let current = selectedWord else { return }
        let allWords = getAllWordsInOrder()
        guard let currentIndex = allWords.firstIndex(of: current), currentIndex > 0 else { return }

        selectedWord = allWords[currentIndex - 1]
        writeLog("⬅️  Previous word: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
    }

    func nextWord() {
        guard let current = selectedWord else { return }
        let allWords = getAllWordsInOrder()
        guard let currentIndex = allWords.firstIndex(of: current), currentIndex < allWords.count - 1 else { return }

        selectedWord = allWords[currentIndex + 1]
        writeLog("➡️  Next word: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
    }

    func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
            writeLog("⬅️  Previous page: \(currentPage)")
        }
    }

    func nextPage() {
        if currentPage < 604 {
            currentPage += 1
            writeLog("➡️  Next page: \(currentPage)")
        }
    }

    func getWordData(surah: Int, ayah: Int, position: Int) -> WordData? {
        return wordDataCache.getWordData(surah: surah, ayah: ayah, position: position)
    }

    func toggleAllWordsHidden(hidden: Bool) {
        wordDataCache.toggleAllWordsHidden(on: currentPage, hidden: hidden)
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
}
