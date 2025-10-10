import SwiftUI
import SwiftData

extension Notification.Name {
    static let previousPage = Notification.Name("previousPage")
    static let nextPage = Notification.Name("nextPage")
    static let previousWord = Notification.Name("previousWord")
    static let nextWord = Notification.Name("nextWord")
    static let previousVerse = Notification.Name("previousVerse")
    static let nextVerse = Notification.Name("nextVerse")
    static let markMistake = Notification.Name("markMistake")
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
    let onMarkMistake: (WordIdentifier) -> Void
    let onAddBookmark: (WordIdentifier) -> Void

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
                                onWordTap: onWordTap,
                                onMarkMistake: onMarkMistake,
                                onAddBookmark: onAddBookmark
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
    let onMarkMistake: (WordIdentifier) -> Void
    let onAddBookmark: (WordIdentifier) -> Void

    @State private var measuredWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if lineInfo?.lineType == "surah_name" {
                    let surahName = lineInfo?.surahNumber != nil ? SurahNames.getName(for: lineInfo!.surahNumber!) : "سُورَةٌ"
                    Text(surahName)
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
                            .contextMenu {
                                Button(action: {
                                    onMarkMistake(wordId)
                                }) {
                                    Label("Mark Mistake", systemImage: "xmark.circle")
                                }

                                Button(action: {
                                    onAddBookmark(wordId)
                                }) {
                                    Label("Add Bookmark", systemImage: "bookmark")
                                }
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
    @Query private var bookmarks: [WordBookmark]
    @StateObject private var wordDataCache: WordDataCache
    @State private var currentPage: Int = 2  // Start at page 2 (Al-Baqarah)
    @State private var lines: [MushafLine] = []
    @State private var lineWords: [Int: [QuranWord]] = [:]
    @State private var showingSettings = false
    @State private var selectedWord: WordIdentifier?
    @State private var isAutoNavigating: Bool = false  // Track if we're auto-turning pages
    @State private var showMistakeToast: Bool = false  // Show toast when mistake is marked
    @State private var isEditingPageNumber: Bool = false  // Track if user is editing page number
    @State private var pageNumberInput: String = ""  // User's page number input
    @State private var showingBookmarkDialog: Bool = false  // Show bookmark dialog
    @State private var bookmarkWordToAdd: WordIdentifier?  // Word to bookmark
    @State private var showingBookmarksList: Bool = false  // Show bookmarks list
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
        ZStack {
            VStack(spacing: 0) {
                // Page header
                HStack {
                Button(action: nextPage) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPage >= 604)

                Spacer()

                if isEditingPageNumber {
                    TextField("Page", text: $pageNumberInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                        .onSubmit {
                            jumpToPage()
                        }
                        .onAppear {
                            pageNumberInput = "\(currentPage)"
                        }
                } else {
                    Text("\(currentPage)")
                        .font(.headline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        .onTapGesture(count: 2) {
                            isEditingPageNumber = true
                        }
                }

                Spacer()

                Button(action: previousPage) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage <= 1)

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)

                // Verse navigation buttons (double chevrons)
                Button(action: nextVerse) {
                    Image(systemName: "chevron.left.2")
                        .foregroundColor(.green)
                }

                Button(action: previousVerse) {
                    Image(systemName: "chevron.right.2")
                        .foregroundColor(.green)
                }

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)

                // Word navigation buttons (single chevrons)
                Button(action: nextWord) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }

                Button(action: previousWord) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)

                // Mistake button (only visible when word is selected)
                if selectedWord != nil {
                    Button(action: markMistake) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }
                    .help("Mark Mistake (X)")

                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 8)
                }

                Button(action: { isTextHidden.toggle() }) {
                    Image(systemName: isTextHidden ? "eye.slash" : "eye")
                        .foregroundColor(isTextHidden ? .orange : .primary)
                }
                .help(isTextHidden ? "Show Text" : "Hide Text")

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)

                Button(action: { showingBookmarksList = true }) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(bookmarks.isEmpty ? .secondary : .blue)
                }
                .help("Bookmarks (\(bookmarks.count))")

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
                onWordTap: handleWordTap,
                onMarkMistake: handleMarkMistake,
                onAddBookmark: handleAddBookmark
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
        .onReceive(NotificationCenter.default.publisher(for: .previousWord)) { _ in
            previousWord()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextWord)) { _ in
            nextWord()
        }
        .onReceive(NotificationCenter.default.publisher(for: .previousVerse)) { _ in
            previousVerse()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextVerse)) { _ in
            nextVerse()
        }
        .onReceive(NotificationCenter.default.publisher(for: .markMistake)) { _ in
            markMistake()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingBookmarkDialog) {
            if let wordId = bookmarkWordToAdd {
                AddBookmarkView(wordId: wordId, wordDataCache: wordDataCache)
            }
        }
        .sheet(isPresented: $showingBookmarksList) {
            BookmarksView(onBookmarkSelected: jumpToBookmark)
        }

            // Toast notification overlay
            if showMistakeToast {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                        Text("Mistake Marked")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.95))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
                .transition(.opacity)
            }
        }
    }

    func loadPage(_ pageNumber: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Clear selection when changing pages (unless auto-navigating)
        if !isAutoNavigating {
            selectedWord = nil
        }
        isAutoNavigating = false  // Reset flag

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
            // Unhide the word when selected
            unhideWord(wordId)
        }
        writeLog("🔘 Word tapped: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
    }

    func unhideWord(_ wordId: WordIdentifier) {
        guard let wordData = wordDataCache.getWordData(surah: wordId.surah, ayah: wordId.ayah, position: wordId.position) else {
            return
        }

        // Only record interaction if the word was actually hidden
        if wordData.isHidden {
            wordData.isHidden = false
            writeLog("👁️ Unhid word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")

            // Record interaction (review) when word is unhidden
            let interaction = WordInteraction(wordData: wordData)
            wordData.interactions.append(interaction)
            modelContext.insert(interaction)

            do {
                try modelContext.save()
                writeLog("📊 Review recorded for word: \(wordId.surah):\(wordId.ayah):\(wordId.position) (total reviews: \(wordData.interactions.count))")
            } catch {
                writeLog("❌ Error saving interaction: \(error)")
            }
        }
    }

    func markMistake() {
        guard let current = selectedWord else {
            writeLog("❌ No word selected to mark mistake")
            return
        }

        guard let wordData = wordDataCache.getWordData(surah: current.surah, ayah: current.ayah, position: current.position) else {
            writeLog("❌ Could not find word data for: \(current.surah):\(current.ayah):\(current.position)")
            return
        }

        let mistake = WordMistake(wordData: wordData)
        wordData.mistakes.append(mistake)
        modelContext.insert(mistake)

        do {
            try modelContext.save()
            writeLog("❌ Mistake marked for word: \(current.surah):\(current.ayah):\(current.position) (total: \(wordData.mistakes.count))")

            // Show toast notification
            withAnimation {
                showMistakeToast = true
            }

            // Hide toast after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    showMistakeToast = false
                }
            }
        } catch {
            writeLog("❌ Error saving mistake: \(error)")
        }
    }

    func handleMarkMistake(_ wordId: WordIdentifier) {
        // Select the word first, then mark mistake
        selectedWord = wordId
        markMistake()
    }

    func handleAddBookmark(_ wordId: WordIdentifier) {
        bookmarkWordToAdd = wordId
        selectedWord = wordId
        showingBookmarkDialog = true
        writeLog("📑 Opening bookmark dialog for word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
    }

    func jumpToBookmark(_ wordId: WordIdentifier) {
        writeLog("📑 Jumping to bookmark: \(wordId.surah):\(wordId.ayah):\(wordId.position)")

        // Find which page contains this word by searching all pages
        var targetPage: Int?

        for page in 1...604 {
            let pageWords = MushafCache.shared.getPageWords(page)

            // Check all lines on this page
            for (_, words) in pageWords {
                for word in words {
                    if word.surah == wordId.surah &&
                       word.ayah == wordId.ayah &&
                       word.word == wordId.position {
                        targetPage = page
                        break
                    }
                }
                if targetPage != nil { break }
            }
            if targetPage != nil { break }
        }

        guard let page = targetPage else {
            writeLog("❌ Could not find page for bookmark: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
            return
        }

        // Navigate to the page
        isAutoNavigating = true
        currentPage = page
        writeLog("📖 Navigated to page \(page)")

        // Select the word after page loads
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.selectedWord = wordId
            self.unhideWord(wordId)
            self.writeLog("✅ Selected bookmark: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
        }
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

    // Get the first word on the current page
    func getFirstWordOnPage() -> WordIdentifier? {
        return getAllWordsInOrder().first
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
        // If nothing is selected, select the first word
        guard let current = selectedWord else {
            if let firstWord = getFirstWordOnPage() {
                selectedWord = firstWord
                unhideWord(firstWord)
                writeLog("🔘 Auto-selected first word: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
            }
            return
        }

        let allWords = getAllWordsInOrder()
        if let currentIndex = allWords.firstIndex(of: current) {
            if currentIndex > 0 {
                // Move to previous word on same page
                selectedWord = allWords[currentIndex - 1]
                unhideWord(allWords[currentIndex - 1])
                writeLog("⬅️  Previous word: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
            } else {
                // At first word, go to previous page and select last word
                if currentPage > 1 {
                    isAutoNavigating = true  // Prevent loadPage from clearing selection
                    currentPage -= 1
                    writeLog("⬅️  Previous page: \(currentPage)")
                    // Selection will happen after page loads via DispatchQueue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let lastWord = self.getAllWordsInOrder().last {
                            self.selectedWord = lastWord
                            self.unhideWord(lastWord)
                            self.writeLog("🔘 Auto-selected last word on page: \(lastWord.surah):\(lastWord.ayah):\(lastWord.position)")
                        }
                    }
                }
            }
        }
    }

    func nextWord() {
        // If nothing is selected, select the first word
        guard let current = selectedWord else {
            if let firstWord = getFirstWordOnPage() {
                selectedWord = firstWord
                unhideWord(firstWord)
                writeLog("🔘 Auto-selected first word: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
            }
            return
        }

        let allWords = getAllWordsInOrder()
        if let currentIndex = allWords.firstIndex(of: current) {
            if currentIndex < allWords.count - 1 {
                // Move to next word on same page
                selectedWord = allWords[currentIndex + 1]
                unhideWord(allWords[currentIndex + 1])
                writeLog("➡️  Next word: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
            } else {
                // At last word, go to next page and select first word
                if currentPage < 604 {
                    isAutoNavigating = true  // Prevent loadPage from clearing selection
                    currentPage += 1
                    writeLog("➡️  Next page: \(currentPage)")
                    // Selection will happen after page loads via DispatchQueue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let firstWord = self.getFirstWordOnPage() {
                            self.selectedWord = firstWord
                            self.unhideWord(firstWord)
                            self.writeLog("🔘 Auto-selected first word on page: \(firstWord.surah):\(firstWord.ayah):\(firstWord.position)")
                        }
                    }
                }
            }
        }
    }

    // Verse navigation
    func canMoveToPreviousVerse() -> Bool {
        guard let current = selectedWord else { return false }
        let allWords = getAllWordsInOrder()

        // Find if there's a word before current that has a different ayah
        for word in allWords.reversed() {
            if word.surah == current.surah && word.ayah < current.ayah {
                return true
            }
        }
        return false
    }

    func canMoveToNextVerse() -> Bool {
        guard let current = selectedWord else { return false }
        let allWords = getAllWordsInOrder()

        // Find if there's a word after current that has a different ayah
        for word in allWords {
            if word.surah == current.surah && word.ayah > current.ayah {
                return true
            }
        }
        return false
    }

    func previousVerse() {
        let allWords = getAllWordsInOrder()

        // If nothing is selected, select the first ayah marker on the page
        guard let current = selectedWord else {
            // Find the first verse's ayah marker
            if let firstWord = allWords.first {
                // Find all words in the first verse
                var firstVerseWords: [WordIdentifier] = []
                for word in allWords {
                    if word.surah == firstWord.surah && word.ayah == firstWord.ayah {
                        firstVerseWords.append(word)
                    } else if !firstVerseWords.isEmpty {
                        break
                    }
                }

                // Select the last word (ayah marker) of the first verse
                if let ayahMarker = firstVerseWords.last {
                    selectedWord = ayahMarker
                    unhideWord(ayahMarker)
                    writeLog("🔘 Auto-selected first verse marker: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
                }
            }
            return
        }

        // Find the last word (ayah marker) of the previous verse on this page
        var previousVerseWords: [WordIdentifier] = []
        for word in allWords {
            if word.surah == current.surah && word.ayah < current.ayah {
                if previousVerseWords.isEmpty || word.ayah == previousVerseWords[0].ayah {
                    previousVerseWords.append(word)
                } else if word.ayah > previousVerseWords[0].ayah {
                    // Found a verse closer to current, replace
                    previousVerseWords = [word]
                }
            }
        }

        // Select the last word of the previous verse (the ayah marker)
        if let lastWord = previousVerseWords.last {
            selectedWord = lastWord
            unhideWord(lastWord)
            writeLog("⬅️⬅️  Previous verse: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
        } else {
            // No previous verse on this page, go to previous page
            if currentPage > 1 {
                isAutoNavigating = true  // Prevent loadPage from clearing selection
                currentPage -= 1
                writeLog("⬅️  Previous page: \(currentPage)")
                // Select the last verse's ayah marker on the new page
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let newPageWords = self.getAllWordsInOrder()
                    if !newPageWords.isEmpty {
                        // Find all words in the last verse
                        var lastVerseWords: [WordIdentifier] = []
                        for word in newPageWords.reversed() {
                            if lastVerseWords.isEmpty || word.ayah == lastVerseWords[0].ayah {
                                lastVerseWords.insert(word, at: 0)
                            } else {
                                break
                            }
                        }

                        if let ayahMarker = lastVerseWords.last {
                            self.selectedWord = ayahMarker
                            self.unhideWord(ayahMarker)
                            self.writeLog("🔘 Auto-selected last verse marker on page: \(ayahMarker.surah):\(ayahMarker.ayah):\(ayahMarker.position)")
                        }
                    }
                }
            }
        }
    }

    func nextVerse() {
        let allWords = getAllWordsInOrder()

        // If nothing is selected, select the first ayah marker on the page
        guard let current = selectedWord else {
            // Find the first verse's ayah marker
            if let firstWord = allWords.first {
                // Find all words in the first verse
                var firstVerseWords: [WordIdentifier] = []
                for word in allWords {
                    if word.surah == firstWord.surah && word.ayah == firstWord.ayah {
                        firstVerseWords.append(word)
                    } else if !firstVerseWords.isEmpty {
                        break
                    }
                }

                // Select the last word (ayah marker) of the first verse
                if let ayahMarker = firstVerseWords.last {
                    selectedWord = ayahMarker
                    unhideWord(ayahMarker)
                    writeLog("🔘 Auto-selected first verse marker: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
                }
            }
            return
        }

        // First, check if we're already at the ayah marker of the current verse
        // Find all words in the current verse
        var currentVerseWords: [WordIdentifier] = []
        for word in allWords {
            if word.surah == current.surah && word.ayah == current.ayah {
                currentVerseWords.append(word)
            }
        }

        // If we're not at the last word of the current verse, jump to it first
        if let currentVerseMarker = currentVerseWords.last, currentVerseMarker != current {
            selectedWord = currentVerseMarker
            unhideWord(currentVerseMarker)
            writeLog("➡️➡️  Jump to current verse marker: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
            return
        }

        // We're at the ayah marker, so find the next verse's ayah marker
        var nextVerseWords: [WordIdentifier] = []
        for word in allWords {
            if word.surah == current.surah && word.ayah > current.ayah {
                if nextVerseWords.isEmpty || word.ayah == nextVerseWords[0].ayah {
                    nextVerseWords.append(word)
                } else {
                    // Found words from a different verse, stop
                    break
                }
            }
        }

        // Select the last word of the next verse (the ayah marker)
        if let lastWord = nextVerseWords.last {
            selectedWord = lastWord
            unhideWord(lastWord)
            writeLog("➡️➡️  Next verse: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
        } else {
            // No next verse on this page, go to next page
            if currentPage < 604 {
                isAutoNavigating = true  // Prevent loadPage from clearing selection
                currentPage += 1
                writeLog("➡️  Next page: \(currentPage)")
                // Select the first verse's ayah marker on the new page
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let newPageWords = self.getAllWordsInOrder()
                    if let firstWord = newPageWords.first {
                        // Find all words in the first verse
                        var firstVerseWords: [WordIdentifier] = []
                        for word in newPageWords {
                            if word.surah == firstWord.surah && word.ayah == firstWord.ayah {
                                firstVerseWords.append(word)
                            } else if !firstVerseWords.isEmpty {
                                break
                            }
                        }

                        if let ayahMarker = firstVerseWords.last {
                            self.selectedWord = ayahMarker
                            self.unhideWord(ayahMarker)
                            self.writeLog("🔘 Auto-selected first verse marker on page: \(ayahMarker.surah):\(ayahMarker.ayah):\(ayahMarker.position)")
                        }
                    }
                }
            }
        }
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

    func jumpToPage() {
        guard let pageNum = Int(pageNumberInput) else {
            writeLog("❌ Invalid page number: \(pageNumberInput)")
            isEditingPageNumber = false
            return
        }

        if pageNum >= 1 && pageNum <= 604 {
            currentPage = pageNum
            writeLog("🔢 Jumped to page: \(currentPage)")
        } else {
            writeLog("❌ Page number out of range: \(pageNum)")
        }

        isEditingPageNumber = false
    }

    func getWordData(surah: Int, ayah: Int, position: Int) -> WordData? {
        return wordDataCache.getWordData(surah: surah, ayah: ayah, position: position)
    }

    func toggleAllWordsHidden(hidden: Bool) {
        // Set hide mode in cache so new pages are automatically hidden
        wordDataCache.setHideMode(enabled: hidden, startPage: currentPage)

        if hidden {
            // Hide current page + next 5 pages (not previous pages)
            let endPage = min(604, currentPage + 5)
            for page in currentPage...endPage {
                wordDataCache.toggleAllWordsHidden(on: page, hidden: hidden)
            }
            writeLog("👁️ Text hidden for pages \(currentPage)-\(endPage)")
        } else {
            // Show entire cache window (current page ± 5 pages)
            let startPage = max(1, currentPage - 5)
            let endPage = min(604, currentPage + 5)
            for page in startPage...endPage {
                wordDataCache.toggleAllWordsHidden(on: page, hidden: hidden)
            }
            writeLog("👁️ Text shown for pages \(startPage)-\(endPage)")
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
}
