import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
typealias PlatformFont = NSFont
#else
import UIKit
typealias PlatformFont = UIFont
#endif

/// Cross-platform font utilities
struct FontUtilities {
    /// Get a font by name and size, with fallback to system font
    static func font(named name: String, size: CGFloat) -> PlatformFont {
        #if os(macOS)
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
        #else
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
        #endif
    }

    /// Calculate the size of a string with given font
    static func size(of text: String, font: PlatformFont) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attributes)
    }

    /// Get available font families (for settings)
    static func availableFontFamilies() -> [String] {
        #if os(macOS)
        return NSFontManager.shared.availableFontFamilies
        #else
        return UIFont.familyNames
        #endif
    }
}

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
struct WordIdentifier: Equatable, Hashable, Identifiable {
    let surah: Int
    let ayah: Int
    let position: Int

    var id: String {
        "\(surah):\(ayah):\(position)"
    }
}

// Helper function to convert English numerals to Arabic numerals
func toArabicNumerals(_ number: Int) -> String {
    let arabicNumerals = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
    return String(number).map { char in
        if let digit = Int(String(char)) {
            return arabicNumerals[digit]
        }
        return String(char)
    }.joined()
}

struct PageContentView: View {
    let currentPage: Int
    let lines: [MushafLine]
    let lineWords: [Int: [QuranWord]]  // lineNumber -> words
    let fontFamily: String
    let baseFontSize: CGFloat
    let lineHeight: CGFloat
    let lineSpacing: CGFloat
    let wordSpacing: CGFloat
    let useQPCV1: Bool  // Use QPC V1 glyph codes
    let getWordData: (Int, Int, Int) -> WordData?
    @Binding var selectedWord: WordIdentifier?
    let onWordTap: (WordIdentifier) -> Void
    let onMarkMistake: (WordIdentifier) -> Void
    let onAddBookmark: (WordIdentifier) -> Void
    let showPageBorder: Bool
    let marginTop: CGFloat
    let marginBottom: CGFloat
    let marginLeft: CGFloat
    let marginRight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            #if os(macOS)
            ScrollView {
                pageContent(geometry: geometry)
            }
            #else
            // On iOS, disable scrolling to prevent interference with swipe gestures
            pageContent(geometry: geometry)
            #endif
        }
    }

    @ViewBuilder
    private func pageContent(geometry: GeometryProxy) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Render all 15 lines
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...15, id: \.self) { lineNum in
                    let lineInfo = lines.first(where: { $0.lineNumber == lineNum })
                    let wordsInLine = lineWords[lineNum] ?? []

                    JustifiedLineView(
                        currentPage: currentPage,
                        lineNumber: lineNum,
                        lineInfo: lineInfo,
                        words: wordsInLine,
                        fontFamily: fontFamily,
                        baseFontSize: baseFontSize,
                        lineHeight: lineHeight,
                        containerWidth: geometry.size.width,
                        useQPCV1: useQPCV1,
                        getWordData: getWordData,
                        selectedWord: $selectedWord,
                        onWordTap: onWordTap,
                        onMarkMistake: onMarkMistake,
                        onAddBookmark: onAddBookmark
                    )
                }
            }
            .padding(.top, marginTop)
            .padding(.bottom, marginBottom)
            .padding(.leading, marginLeft)
            .padding(.trailing, marginRight)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.gray, lineWidth: showPageBorder ? 1 : 0)
        )
        // .padding()
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
    let currentPage: Int
    let lineNumber: Int
    let lineInfo: MushafLine?
    let words: [QuranWord]
    let fontFamily: String
    let baseFontSize: CGFloat
    let lineHeight: CGFloat
    let containerWidth: CGFloat  // Not used anymore, keeping for compatibility
    let useQPCV1: Bool  // Use QPC V1 glyph codes
    let getWordData: (Int, Int, Int) -> WordData?
    @Binding var selectedWord: WordIdentifier?
    let onWordTap: (WordIdentifier) -> Void
    let onMarkMistake: (WordIdentifier) -> Void
    let onAddBookmark: (WordIdentifier) -> Void

    @State private var measuredWidth: CGFloat = 0

    // Check if this is a special page (1, 2, 602, 603, 604)
    private var isSpecialPage: Bool {
        currentPage == 1 || currentPage == 2 || currentPage == 602 || currentPage == 603 || currentPage == 604
    }

    // Use QPC surah name font v2
    private var surahNameFont: String {
        return "surah-name-v2"
    }

    // Get the proper font for the current platform
    private func getFont(fontName: String, size: CGFloat) -> Font {
        #if os(iOS)
        // iOS implementation - simpler, just use custom or system
        if UIFont(name: fontName, size: 12) != nil {
            return .custom(fontName, size: size)
        }
        // Final fallback to system font
        return .system(size: size)

        #elseif os(macOS)
        // macOS implementation - SwiftUI's .custom() doesn't work with runtime-registered fonts
        // We MUST use Font(nsFont) with the actual NSFont instance
        if let nsFont = NSFont(name: fontName, size: size) {
            return Font(nsFont)
        }
        // Final fallback to system font
        return .system(size: size)
        #endif
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .center) {
                if lineInfo?.lineType == "surah_name", let surahNumber = lineInfo?.surahNumber {
                    let surahName = SurahNames.getName(for: surahNumber)
                    let verseCount = SurahInfo.getVerseCount(for: surahNumber)

                    HStack(spacing: 0) {
                        // Right section: Surah number centered in available space
                        HStack(spacing: 4) {
                            Text("ترتيبها")
                                .font(getFont(fontName: "ScheherazadeNew-Regular", size: baseFontSize * 0.4))
                            Text(toArabicNumerals(surahNumber))
                                .font(getFont(fontName: "ScheherazadeNew-Regular", size: baseFontSize * 0.4))
                        }
                        .frame(maxWidth: .infinity)

                        // Center: Surah name (takes only as much space as it needs)
                        Text(surahName)
                            .font(getFont(fontName: surahNameFont, size: baseFontSize * 1.28))

                        // Left section: Verse count centered in available space
                        HStack(spacing: 4) {
                            Text("آياتها")
                                .font(getFont(fontName: "ScheherazadeNew-Regular", size: baseFontSize * 0.4))
                            Text(toArabicNumerals(verseCount))
                                .font(getFont(fontName: "ScheherazadeNew-Regular", size: baseFontSize * 0.4))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if lineInfo?.lineType == "basmallah" {
                    // Use ornamental Basmala glyph (U+FDFD): ﷽
                    Text("﷽")
                        .font(getFont(fontName: fontFamily, size: baseFontSize))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let positions = calculateWordPositions(containerWidth: geo.size.width)

                    ForEach(Array(words.enumerated()), id: \.element.id) { index, quranWord in
                        let wordData = getWordData(quranWord.surah, quranWord.ayah, quranWord.word)
                        let wordId = WordIdentifier(surah: quranWord.surah, ayah: quranWord.ayah, position: quranWord.word)
                        let isSelected = selectedWord == wordId

                        Text(quranWord.text)
                            .font(getFont(fontName: fontFamily, size: baseFontSize))
                            .opacity(wordData?.isHidden == true ? 0 : 1)
                            .allowsHitTesting(wordData?.isHidden != true)  // Pass through touches when hidden
                            .padding(.horizontal, 4)
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
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .stroke(Color.white, lineWidth: lineInfo?.lineType == "surah_name" ? 0.5 : 0)
            )
        }
        .frame(height: lineHeight)
    }

    private func calculateWordWidths() -> [CGFloat] {
        let font = FontUtilities.font(named: fontFamily, size: baseFontSize)
        var wordWidths: [CGFloat] = []

        for word in words {
            let size = FontUtilities.size(of: word.text, font: font)
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

        var positions: [Int: CGFloat] = [:]

        if isSpecialPage {
            // For special pages (1, 2, 602, 603, 604): center words with minimal spacing
            let minSpacing: CGFloat = 10  // Minimal fixed spacing between words
            let totalWidth = totalTextWidth + (CGFloat(words.count - 1) * minSpacing)

            // Start from center and work outward (RTL)
            var currentX = (containerWidth + totalWidth) / 2

            for (index, width) in wordWidths.enumerated().reversed() {
                currentX -= width / 2  // Center of word
                positions[index] = currentX
                currentX -= width / 2  // Other half of word
                currentX -= minSpacing  // Fixed minimal spacing
            }
        } else {
            // For normal pages: justified spacing
            let gaps = CGFloat(words.count - 1)
            let spacing = gaps > 0 ? max(0, (containerWidth - totalTextWidth) / gaps) : 0

            // Calculate x-position for each word (RTL, so first word on right, last word on left)
            var currentX = containerWidth

            for (index, width) in wordWidths.enumerated().reversed() {
                currentX -= width / 2  // Center of word
                positions[index] = currentX
                currentX -= width / 2  // Other half of word
                currentX -= spacing  // Space to next word
            }
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
    @AppStorage("currentPage") private var currentPage: Int = 2  // Start at page 2 (Al-Baqarah)
    @State private var lines: [MushafLine] = []
    @State private var lineWords: [Int: [QuranWord]] = [:]
    @State private var showingSettings = false
    @State private var selectedWord: WordIdentifier?
    @State private var isAutoNavigating: Bool = false  // Track if we're auto-turning pages
    @State private var showMistakeToast: Bool = false  // Show toast when mistake is marked
    @State private var isEditingPageNumber: Bool = false  // Track if user is editing page number
    @State private var pageNumberInput: String = ""  // User's page number input
    @State private var bookmarkWordToAdd: WordIdentifier?  // Word to bookmark (triggers sheet when set)
    @State private var showingBookmarksList: Bool = false  // Show bookmarks list
    @State private var showingAudioMode: Bool = false  // Show audio memorization mode
    @State private var windowWidth: CGFloat = 0  // Track window width for 2-page mode calculation
    @State private var linesLeft: [MushafLine] = []  // For even page (left side)
    @State private var lineWordsLeft: [Int: [QuranWord]] = [:]  // For even page (left side)
    @Binding var isTextHidden: Bool
    @FocusState private var pageFieldFocused: Bool
    @State private var showInvalidPageToast: Bool = false
    @State private var loadNextPageVisible: Bool = false  // Flag to load next page as visible

    init(isTextHidden: Binding<Bool>, modelContext: ModelContext) {
        self._isTextHidden = isTextHidden
        self._wordDataCache = StateObject(wrappedValue: WordDataCache(modelContext: modelContext))
    }

    // Settings from AppStorage
    @AppStorage("fontSize") private var fontSize: Double = 28
    @AppStorage("lineHeightMultiplier") private var lineHeightMultiplier: Double = 2.2
    @AppStorage("fontFamily") private var fontFamily: String = "KFGQPCUthmanTahaNaskh"
    @AppStorage("useQPCV1") private var useQPCV1: Bool = true  // QPC V1 fonts with glyph codes
    @AppStorage("showPageBorder") private var showPageBorder: Bool = false
    @AppStorage("pageMarginTop") private var pageMarginTop: Double = 0
    @AppStorage("pageMarginBottom") private var pageMarginBottom: Double = 0
    @AppStorage("pageMarginLeft") private var pageMarginLeft: Double = 32
    @AppStorage("pageMarginRight") private var pageMarginRight: Double = 32

    // Layout constants - all relative to base font size
    var baseFontSize: CGFloat { CGFloat(fontSize) }
    var lineHeight: CGFloat { baseFontSize * CGFloat(lineHeightMultiplier) }  // Line height = multiplier x font size
    var lineSpacing: CGFloat { lineHeight * 0.25 }  // Spacing = 1/4 of line height
    var wordSpacing: CGFloat { baseFontSize * 0.15 } // Word spacing = 15% of font size

    // Dynamic font family based on current page (for QPC V1)
    var currentFontFamily: String {
        if useQPCV1 {
            return "QCF_P\(String(format: "%03d", currentPage))"  // QPC V1 uses QCF_P001, QCF_P002, ... QCF_P604
        } else {
            return fontFamily  // Use selected font from settings
        }
    }

    // Single source of truth: Check if we should be in 2-page mode
    var shouldShowTwoPages: Bool {
        guard currentPage < 604 && windowWidth > 0 else { return false }
        let oddPageWidth = calculateMinimumPageWidth(for: currentPage)
        let evenPageWidth = calculateMinimumPageWidth(for: currentPage + 1)
        let maxPageWidth = max(oddPageWidth, evenPageWidth)
        return windowWidth >= 2 * maxPageWidth
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Page content with GeometryReader to track window width
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        if shouldShowTwoPages {
                            // Even page on LEFT
                            PageContentView(
                                currentPage: currentPage + 1,
                                lines: linesLeft,
                                lineWords: lineWordsLeft,
                                fontFamily: useQPCV1 ? "QCF_P\(String(format: "%03d", currentPage + 1))" : fontFamily,
                                baseFontSize: baseFontSize,
                                lineHeight: lineHeight,
                                lineSpacing: lineSpacing,
                                wordSpacing: wordSpacing,
                                useQPCV1: useQPCV1,
                                getWordData: getWordData,
                                selectedWord: $selectedWord,
                                onWordTap: handleWordTap,
                                onMarkMistake: handleMarkMistake,
                                onAddBookmark: handleAddBookmark,
                                showPageBorder: showPageBorder,
                                marginTop: CGFloat(pageMarginTop),
                                marginBottom: CGFloat(pageMarginBottom),
                                marginLeft: CGFloat(pageMarginLeft),
                                marginRight: CGFloat(pageMarginRight)
                            )
                            .frame(width: windowWidth / 2)

                            // Odd page on RIGHT
                            PageContentView(
                                currentPage: currentPage,
                                lines: lines,
                                lineWords: lineWords,
                                fontFamily: currentFontFamily,
                                baseFontSize: baseFontSize,
                                lineHeight: lineHeight,
                                lineSpacing: lineSpacing,
                                wordSpacing: wordSpacing,
                                useQPCV1: useQPCV1,
                                getWordData: getWordData,
                                selectedWord: $selectedWord,
                                onWordTap: handleWordTap,
                                onMarkMistake: handleMarkMistake,
                                onAddBookmark: handleAddBookmark,
                                showPageBorder: showPageBorder,
                                marginTop: CGFloat(pageMarginTop),
                                marginBottom: CGFloat(pageMarginBottom),
                                marginLeft: CGFloat(pageMarginLeft),
                                marginRight: CGFloat(pageMarginRight)
                            )
                            .frame(width: windowWidth / 2)
                        } else {
                            // Single page mode (odd page only)
                            PageContentView(
                                currentPage: currentPage,
                                lines: lines,
                                lineWords: lineWords,
                                fontFamily: currentFontFamily,
                                baseFontSize: baseFontSize,
                                lineHeight: lineHeight,
                                lineSpacing: lineSpacing,
                                wordSpacing: wordSpacing,
                                useQPCV1: useQPCV1,
                                getWordData: getWordData,
                                selectedWord: $selectedWord,
                                onWordTap: handleWordTap,
                                onMarkMistake: handleMarkMistake,
                                onAddBookmark: handleAddBookmark,
                                showPageBorder: showPageBorder,
                                marginTop: CGFloat(pageMarginTop),
                                marginBottom: CGFloat(pageMarginBottom),
                                marginLeft: CGFloat(pageMarginLeft),
                                marginRight: CGFloat(pageMarginRight)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .background(Color.clear)
                    #if !os(macOS)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let horizontalAmount = abs(value.translation.width)
                                let verticalAmount = abs(value.translation.height)

                                writeLog("👆 Swipe detected: H=\(String(format: "%.1f", value.translation.width)) V=\(String(format: "%.1f", value.translation.height)) hidden=\(isTextHidden)")

                                if isTextHidden {
                                    // HIDDEN MODE: Swipes trigger navigation actions
                                    writeLog("🔒 Hidden mode active")
                                    if horizontalAmount > verticalAmount {
                                        // Horizontal swipes
                                        if value.translation.width < 0 {
                                            // Swipe left -> click left chevron (blue) -> next word
                                            writeLog("⬅️ Swipe left -> next word")
                                            nextWord()
                                        } else {
                                            // Swipe right -> click right chevron (blue) -> previous word
                                            writeLog("➡️ Swipe right -> previous word")
                                            previousWord()
                                        }
                                    } else {
                                        // Vertical swipes
                                        if value.translation.height < 0 {
                                            // Swipe up -> click double right chevron (green) -> previous verse
                                            writeLog("⬆️ Swipe up -> previous verse")
                                            previousVerse()
                                        } else {
                                            // Swipe down -> click double left chevron (green) -> next verse
                                            writeLog("⬇️ Swipe down -> next verse")
                                            nextVerse()
                                        }
                                    }
                                } else {
                                    // NORMAL MODE: Only horizontal swipes for page navigation
                                    writeLog("👁️ Normal mode active")
                                    // Only trigger if the swipe is predominantly horizontal
                                    guard horizontalAmount > verticalAmount else {
                                        writeLog("❌ Vertical swipe ignored in normal mode")
                                        return
                                    }

                                    // RTL (right-to-left) swipe directions:
                                    // Swipe left = go back (previous page in reading order)
                                    // Swipe right = go forward (next page in reading order)
                                    if value.translation.width < 0 {
                                        // Swiped left -> previous page (going backwards in Quran)
                                        writeLog("⬅️ Swipe left -> previous page")
                                        previousPage()
                                    } else if value.translation.width > 0 {
                                        // Swiped right -> next page (going forward in Quran)
                                        writeLog("➡️ Swipe right -> next page")
                                        nextPage()
                                    }
                                }
                            }
                    )
                    #endif
                    .onAppear {
                        windowWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { oldValue, newValue in
                        windowWidth = newValue
                        let oddW = calculateMinimumPageWidth(for: currentPage)
                        let evenW = currentPage < 604 ? calculateMinimumPageWidth(for: currentPage + 1) : 0
                        let need = 2 * max(oddW, evenW)
                        writeLog("📐 Width change: window=\(String(format: "%.1f", newValue)) need=\(String(format: "%.1f", need)) (odd=\(String(format: "%.1f", oddW)), even=\(String(format: "%.1f", evenW)))")
                    }
                    .onChange(of: shouldShowTwoPages) { oldValue, newValue in
                        // Reload page when 2-page mode changes
                        if oldValue != newValue {
                            loadPage(currentPage)
                        }
                    }
                }

                // Page footer (navigation bar)
                HStack {
                #if os(macOS)
                Button(action: nextPage) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPage >= 604)

                Spacer()
                #endif

                if isEditingPageNumber {
                    HStack(spacing: 8) {
                        TextField("Page", text: $pageNumberInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                            .focused($pageFieldFocused)
                            #if !os(macOS)
                            .keyboardType(.numberPad)
                            #endif
                            .onChange(of: pageNumberInput) { oldValue, newValue in
                                // Filter non-digits
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    pageNumberInput = filtered
                                }
                            }
                            .onAppear {
                                pageNumberInput = "\(currentPage)"
                                pageFieldFocused = true
                                // Auto-select text after focus is set
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    #if os(iOS)
                                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                    #endif
                                }
                            }
                            #if !os(macOS)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()

                                    Button(action: {
                                        isEditingPageNumber = false
                                        pageFieldFocused = false
                                        pageNumberInput = "\(currentPage)"
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }

                                    Button(action: {
                                        jumpToPage()
                                    }) {
                                        Text("Go")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            #else
                            .onSubmit {
                                jumpToPage()
                            }
                            #endif

                        Button(action: {
                            isEditingPageNumber = false
                            pageFieldFocused = false
                            pageNumberInput = "\(currentPage)"
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("\(currentPage)")
                        .font(.headline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        #if os(macOS)
                        .onTapGesture(count: 2) {
                            isEditingPageNumber = true
                        }
                        #else
                        .onTapGesture {
                            isEditingPageNumber = true
                            pageFieldFocused = true
                        }
                        #endif
                }

                #if os(macOS)
                Spacer()

                Button(action: previousPage) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage <= 1)

                // Verse navigation buttons (double chevrons)
                Button(action: nextVerse) {
                    Image(systemName: "chevron.left.2")
                        .foregroundColor(.green)
                }

                Button(action: previousVerse) {
                    Image(systemName: "chevron.right.2")
                        .foregroundColor(.green)
                }

                // Word navigation buttons (single chevrons)
                Button(action: nextWord) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }

                Button(action: previousWord) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
                #endif

                Spacer()

                Button(action: { isTextHidden.toggle() }) {
                    Image(systemName: isTextHidden ? "eye.slash" : "eye")
                        .foregroundColor(isTextHidden ? .orange : .primary)
                }
                .help(isTextHidden ? "Show Text" : "Hide Text")

                Spacer()

                Button(action: { showingBookmarksList = true }) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(bookmarks.isEmpty ? .secondary : .blue)
                }
                .help("Bookmarks (\(bookmarks.count))")

                Spacer()

                Button(action: { showingAudioMode = true }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(AudioService.shared.isNetworkAvailable() ? .green : .gray)
                }
                .help("Audio Mode")
                .disabled(!AudioService.shared.isNetworkAvailable())

                Spacer()

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            }
            .onAppear {
                loadPage(currentPage)
            }
        .onChange(of: currentPage) { oldValue, newValue in
            loadPage(newValue, hidden: loadNextPageVisible ? false : nil)
            loadNextPageVisible = false  // Reset flag
        }
        .onChange(of: isTextHidden) { oldValue, newValue in
            toggleAllWordsHidden(hidden: newValue)
        }
        .onChange(of: pageFieldFocused) { oldValue, newValue in
            // When focus is lost, exit edit mode
            if !newValue && isEditingPageNumber {
                isEditingPageNumber = false
                pageNumberInput = "\(currentPage)"
            }
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
            SettingsView(onPageSelected: { page in
                currentPage = page
                writeLog("📖 Navigated to page \(page) from history")
            })
        }
        .sheet(item: $bookmarkWordToAdd) { wordId in
            AddBookmarkView(wordId: wordId, wordDataCache: wordDataCache)
        }
        .sheet(isPresented: $showingBookmarksList) {
            BookmarksView(onBookmarkSelected: jumpToBookmark, onErrorSelected: jumpToError)
        }
        .sheet(isPresented: $showingAudioMode) {
            // Get page words for the current page
            let pageWords = MushafCache.shared.getPageWords(currentPage)
            let pageWordsArray = pageWords
                .sorted { $0.key < $1.key }
                .map { (line: $0.key, words: $0.value) }

            AudioMemorizationView(
                currentPage: $currentPage,
                pageWords: pageWordsArray,
                onPageAdvance: { nextPage in
                    // Fetch page data for the next page
                    let nextPageWords = MushafCache.shared.getPageWords(nextPage)
                    return nextPageWords
                        .sorted { $0.key < $1.key }
                        .map { (line: $0.key, words: $0.value) }
                }
            )
        }

            // Toast notification overlays
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

            if showInvalidPageToast {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                        Text("Page must be 1-604")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.95))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
                .transition(.opacity)
            }
        }
    }

    func loadPage(_ pageNumber: Int, hidden: Bool? = nil) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Clear selection when changing pages (unless auto-navigating)
        if !isAutoNavigating {
            selectedWord = nil
        }
        isAutoNavigating = false  // Reset flag

        // Use provided hidden state, or default to current isTextHidden
        let applyHidden = hidden ?? isTextHidden

        // In 2-page mode, ensure we always have an odd page number
        // In single-page mode, use the page number as-is
        let actualPage: Int
        if shouldShowTwoPages {
            actualPage = pageNumber % 2 == 0 ? pageNumber - 1 : pageNumber
        } else {
            actualPage = pageNumber
        }
        let evenPage = actualPage + 1

        // Load current page synchronously (fast)
        MushafCache.shared.ensureCurrentPageLoaded(actualPage)
        if shouldShowTwoPages && evenPage <= 604 {
            MushafCache.shared.ensureCurrentPageLoaded(evenPage)
        }

        // Load current page WordData synchronously
        wordDataCache.preloadCurrentPage(actualPage)
        if shouldShowTwoPages && evenPage <= 604 {
            wordDataCache.preloadCurrentPage(evenPage)
        }

        // Load surrounding pages asynchronously (doesn't block UI)
        DispatchQueue.global(qos: .userInitiated).async {
            MushafCache.shared.ensurePagesLoaded(around: actualPage, range: 5)
        }

        // Load surrounding WordData asynchronously
        Task { @MainActor in
            wordDataCache.preloadPages(around: actualPage)
        }

        // Load the main page
        lines = MushafCache.shared.getLinesForPage(actualPage)
        lineWords = MushafCache.shared.getPageWords(actualPage)

        // If in 2-page mode and not at the last page, also load the even page (left side)
        if shouldShowTwoPages && evenPage <= 604 {
            linesLeft = MushafCache.shared.getLinesForPage(evenPage)
            lineWordsLeft = MushafCache.shared.getPageWords(evenPage)

            // Apply hide mode to both pages
            wordDataCache.toggleAllWordsHidden(on: actualPage, hidden: applyHidden)
            wordDataCache.toggleAllWordsHidden(on: evenPage, hidden: applyHidden)

            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            writeLog("📄 Loaded pages \(actualPage)-\(evenPage) in \(String(format: "%.2f", elapsed))ms (mode: \(applyHidden ? "hidden" : "visible"))")
        } else {
            // Single page mode
            wordDataCache.toggleAllWordsHidden(on: actualPage, hidden: applyHidden)

            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            writeLog("📄 Loaded page \(actualPage) in \(String(format: "%.2f", elapsed))ms (mode: \(applyHidden ? "hidden" : "visible"))")
        }
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
        selectedWord = wordId
        bookmarkWordToAdd = wordId
        writeLog("📑 Opening bookmark dialog for word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
    }

    func jumpToError(_ wordId: WordIdentifier) {
        writeLog("❌ Jumping to error word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")

        // Find the PREVIOUS verse's END (ayah marker) to give user a chance to practice
        // Search all pages to find the word and its previous verse
        for page in 1...604 {
            let pageWords = MushafCache.shared.getPageWords(page)
            var allPageWords: [QuranWord] = []

            for lineNum in 1...15 {
                if let words = pageWords[lineNum] {
                    allPageWords.append(contentsOf: words)
                }
            }

            // Check if error word is on this page
            if let errorWordIndex = allPageWords.firstIndex(where: { $0.surah == wordId.surah && $0.ayah == wordId.ayah && $0.word == wordId.position }) {
                // Found the error word! Now find previous verse's last word
                let errorWord = allPageWords[errorWordIndex]

                // Find previous verse (same surah, ayah-1, or previous surah's last verse)
                var targetWord: QuranWord? = nil

                // Search backwards for previous verse's last word
                for i in (0..<errorWordIndex).reversed() {
                    let word = allPageWords[i]
                    // If we find a word from the previous ayah, continue to find its last word
                    if word.surah == errorWord.surah && word.ayah == errorWord.ayah - 1 {
                        // Continue finding the last word of this verse
                        targetWord = word
                        break
                    } else if word.surah < errorWord.surah || (word.surah == errorWord.surah && word.ayah < errorWord.ayah - 1) {
                        // Went too far back, no previous verse on this page
                        break
                    }
                }

                // If no previous verse found on this page, need to search previous pages
                if targetWord == nil && page > 1 {
                    // Search previous pages for the previous verse
                    for prevPage in (1..<page).reversed() {
                        let prevPageWords = MushafCache.shared.getPageWords(prevPage)
                        var allPrevPageWords: [QuranWord] = []

                        for lineNum in 1...15 {
                            if let words = prevPageWords[lineNum] {
                                allPrevPageWords.append(contentsOf: words)
                            }
                        }

                        // Find the last word of the previous verse
                        for word in allPrevPageWords.reversed() {
                            if word.surah == errorWord.surah && word.ayah == errorWord.ayah - 1 {
                                targetWord = word
                                // Navigate to this page
                                isAutoNavigating = true
                                currentPage = prevPage
                                writeLog("📖 Navigated to page \(prevPage)")

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    let targetId = WordIdentifier(surah: word.surah, ayah: word.ayah, position: word.word)
                                    self.selectedWord = targetId

                                    // If in hidden mode, unhide all verses up to and including the target verse
                                    if self.isTextHidden {
                                        self.unhideVersesBeforeError(targetPage: prevPage, errorWord: errorWord)
                                    } else {
                                        self.unhideWord(targetId)
                                    }

                                    self.writeLog("✅ Selected previous verse end: \(word.surah):\(word.ayah):\(word.word)")
                                }
                                return
                            } else if word.surah < errorWord.surah {
                                // Found previous surah's last ayah
                                targetWord = word
                                isAutoNavigating = true
                                currentPage = prevPage
                                writeLog("📖 Navigated to page \(prevPage)")

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    let targetId = WordIdentifier(surah: word.surah, ayah: word.ayah, position: word.word)
                                    self.selectedWord = targetId

                                    // If in hidden mode, unhide all verses up to and including the target verse
                                    if self.isTextHidden {
                                        self.unhideVersesBeforeError(targetPage: prevPage, errorWord: errorWord)
                                    } else {
                                        self.unhideWord(targetId)
                                    }

                                    self.writeLog("✅ Selected previous surah's last verse: \(word.surah):\(word.ayah):\(word.word)")
                                }
                                return
                            }
                        }
                    }
                }

                // If we found the target on the same page
                if let target = targetWord {
                    isAutoNavigating = true
                    currentPage = page
                    writeLog("📖 Navigated to page \(page)")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let targetId = WordIdentifier(surah: target.surah, ayah: target.ayah, position: target.word)
                        self.selectedWord = targetId

                        // If in hidden mode, unhide all verses up to and including the target verse
                        if self.isTextHidden {
                            self.unhideVersesBeforeError(targetPage: page, errorWord: errorWord)
                        } else {
                            self.unhideWord(targetId)
                        }

                        self.writeLog("✅ Selected previous verse end: \(target.surah):\(target.ayah):\(target.word)")
                    }
                    return
                } else {
                    // No previous verse found (must be first verse of first surah)
                    // Just go to the error word itself
                    isAutoNavigating = true
                    currentPage = page
                    writeLog("📖 Navigated to page \(page)")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.selectedWord = wordId
                        self.unhideWord(wordId)
                        self.writeLog("✅ Selected error word (first verse): \(wordId.surah):\(wordId.ayah):\(wordId.position)")
                    }
                    return
                }
            }
        }

        writeLog("❌ Could not find error word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
    }

    // Helper function to unhide all verses before the error verse and hide the error verse and after
    func unhideVersesBeforeError(targetPage: Int, errorWord: QuranWord) {
        writeLog("👁️ Unhiding verses before error: \(errorWord.surah):\(errorWord.ayah)")

        // Get all words on the target page
        let pageWords = MushafCache.shared.getPageWords(targetPage)
        var allPageWords: [QuranWord] = []

        for lineNum in 1...15 {
            if let words = pageWords[lineNum] {
                allPageWords.append(contentsOf: words)
            }
        }

        var unhiddenCount = 0
        var hiddenCount = 0

        // Process all words on the page
        for word in allPageWords {
            if let wordData = wordDataCache.getWordData(surah: word.surah, ayah: word.ayah, position: word.word) {
                // Check if this word is before the error verse
                let isBeforeError = (word.surah < errorWord.surah) ||
                                   (word.surah == errorWord.surah && word.ayah < errorWord.ayah)

                // Check if this word is in the error verse or after
                let isErrorOrAfter = (word.surah > errorWord.surah) ||
                                    (word.surah == errorWord.surah && word.ayah >= errorWord.ayah)

                if isBeforeError {
                    // Unhide words before the error verse
                    if wordData.isHidden {
                        wordData.isHidden = false
                        unhiddenCount += 1
                    }
                } else if isErrorOrAfter {
                    // Hide the error verse and everything after it
                    if !wordData.isHidden {
                        wordData.isHidden = true
                        hiddenCount += 1
                    }
                }
            }
        }

        if unhiddenCount > 0 || hiddenCount > 0 {
            do {
                try modelContext.save()
                writeLog("✅ Unhid \(unhiddenCount) words before error, hid \(hiddenCount) words from error onwards")
            } catch {
                writeLog("❌ Error updating word visibility: \(error)")
            }
        }
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

    // Get all words on current page(s) in order
    func getAllWordsInOrder() -> [WordIdentifier] {
        var allWords: [WordIdentifier] = []

        // In 2-page mode, include words from both pages (odd page first, then even page)
        if shouldShowTwoPages {
            // First, add words from odd page (right side)
            let sortedLineNumbers = lineWords.keys.sorted()
            for lineNum in sortedLineNumbers {
                if let words = lineWords[lineNum] {
                    for word in words {
                        allWords.append(WordIdentifier(surah: word.surah, ayah: word.ayah, position: word.word))
                    }
                }
            }

            // Then, add words from even page (left side)
            let sortedLineNumbersLeft = lineWordsLeft.keys.sorted()
            for lineNum in sortedLineNumbersLeft {
                if let words = lineWordsLeft[lineNum] {
                    for word in words {
                        allWords.append(WordIdentifier(surah: word.surah, ayah: word.ayah, position: word.word))
                    }
                }
            }
        } else {
            // Single page mode - only use lineWords
            let sortedLineNumbers = lineWords.keys.sorted()
            for lineNum in sortedLineNumbers {
                if let words = lineWords[lineNum] {
                    for word in words {
                        allWords.append(WordIdentifier(surah: word.surah, ayah: word.ayah, position: word.word))
                    }
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
                let previousWordId = allWords[currentIndex - 1]

                // In hidden mode, hide the current word when going backwards
                if isTextHidden {
                    if let wordData = wordDataCache.getWordData(surah: current.surah, ayah: current.ayah, position: current.position) {
                        if !wordData.isHidden {
                            wordData.isHidden = true
                            do {
                                try modelContext.save()
                                writeLog("🔄 Hid word for practice: \(current.surah):\(current.ayah):\(current.position)")
                            } catch {
                                writeLog("❌ Error hiding word: \(error)")
                            }
                        }
                    }
                }

                // Move to previous word on same page
                selectedWord = previousWordId
                unhideWord(previousWordId)
                writeLog("⬅️  Previous word: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
            } else {
                // At first word - check if there are any visible words on the current page
                let hasVisibleWords = allWords.contains { wordId in
                    if let wordData = wordDataCache.getWordData(surah: wordId.surah, ayah: wordId.ayah, position: wordId.position) {
                        return !wordData.isHidden
                    }
                    return false
                }

                if hasVisibleWords {
                    // There are still visible words, so hide the current word and stay on page
                    if let wordData = wordDataCache.getWordData(surah: current.surah, ayah: current.ayah, position: current.position) {
                        if !wordData.isHidden {
                            wordData.isHidden = true
                            do {
                                try modelContext.save()
                                writeLog("🔒 Hid current word: \(current.surah):\(current.ayah):\(current.position) (preparing to go back)")
                            } catch {
                                writeLog("❌ Error hiding current word: \(error)")
                            }
                        }
                    }
                    writeLog("⬅️  Previous word: Hid current word, staying on page")
                } else {
                    // No visible words left, go to previous page (show page, select last word - reviewing what was already studied)
                    if currentPage > 1 {
                        isAutoNavigating = true  // Prevent loadPage from clearing selection

                        // Check if we're in 2-page mode and navigate accordingly
                        if shouldShowTwoPages {
                            currentPage = max(1, currentPage - 2)
                        } else {
                            currentPage -= 1
                        }

                        writeLog("⬅️  Previous page: \(currentPage)")
                        // Unhide the page and select the last word
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Show the page (override hide mode for going backwards)
                            if self.shouldShowTwoPages {
                                let oddPage = self.currentPage % 2 == 0 ? self.currentPage - 1 : self.currentPage
                                let evenPage = oddPage + 1
                                self.wordDataCache.toggleAllWordsHidden(on: oddPage, hidden: false)
                                if evenPage <= 604 {
                                    self.wordDataCache.toggleAllWordsHidden(on: evenPage, hidden: false)
                                }
                            } else {
                                self.wordDataCache.toggleAllWordsHidden(on: self.currentPage, hidden: false)
                            }

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
                // At last word, go to next page (don't select anything - let user guess first)
                if currentPage < 604 {
                    // Check if we're in 2-page mode and navigate accordingly
                    if shouldShowTwoPages {
                        currentPage = min(603, currentPage + 2)
                    } else {
                        currentPage += 1
                    }
                    selectedWord = nil  // Clear selection
                    writeLog("➡️  Next page: \(currentPage) (ready to guess)")
                }
            }
        }
    }

    // Find the previous verse's ayah marker (last word of previous verse)
    func findPreviousVerseMarker(from current: WordIdentifier, in allWords: [WordIdentifier]) -> WordIdentifier? {
        // Find current word's index
        guard let currentIndex = allWords.firstIndex(of: current) else { return nil }

        // Go backwards to find first word from a different verse
        var previousVerseMarker: WordIdentifier? = nil
        for index in (0..<currentIndex).reversed() {
            let word = allWords[index]

            // Check if this word is from a different verse
            let isDifferentVerse = (word.surah != current.surah) || (word.ayah != current.ayah)

            if isDifferentVerse {
                // Found a word from previous verse
                // Now find the last word of that verse (the ayah marker)
                previousVerseMarker = word

                // Continue forward while staying in the same verse to find the marker
                for nextIndex in (index + 1)..<currentIndex {
                    let nextWord = allWords[nextIndex]
                    if nextWord.surah == word.surah && nextWord.ayah == word.ayah {
                        previousVerseMarker = nextWord
                    } else {
                        break
                    }
                }

                return previousVerseMarker
            }
        }

        return nil
    }

    // Find the next verse's ayah marker (last word of next verse)
    func findNextVerseMarker(from current: WordIdentifier, in allWords: [WordIdentifier]) -> WordIdentifier? {
        // Find current word's index
        guard let currentIndex = allWords.firstIndex(of: current) else { return nil }

        // Go forward to find first word from a different verse
        var nextVerseMarker: WordIdentifier? = nil
        for index in (currentIndex + 1)..<allWords.count {
            let word = allWords[index]

            // Check if this word is from a different verse
            let isDifferentVerse = (word.surah != current.surah) || (word.ayah != current.ayah)

            if isDifferentVerse {
                // Found a word from next verse
                // Now find the last word of that verse (the ayah marker)
                nextVerseMarker = word

                // Continue forward while staying in the same verse to find the marker
                for nextIndex in (index + 1)..<allWords.count {
                    let nextWord = allWords[nextIndex]
                    if nextWord.surah == word.surah && nextWord.ayah == word.ayah {
                        nextVerseMarker = nextWord
                    } else {
                        break
                    }
                }

                return nextVerseMarker
            }
        }

        return nil
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

        // If nothing is selected, go to previous page and select last aya marker
        guard let current = selectedWord else {
            if currentPage > 1 {
                isAutoNavigating = true
                loadNextPageVisible = true

                // Check if we're in 2-page mode and navigate accordingly
                if shouldShowTwoPages {
                    currentPage = max(1, currentPage - 2)
                } else {
                    currentPage -= 1
                }

                writeLog("⬅️  Previous page: \(currentPage)")

                // After page loads, select the last aya marker
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let newPageWords = self.getAllWordsInOrder()
                    if let lastWord = newPageWords.last {
                        self.selectedWord = lastWord
                        self.writeLog("🔘 Selected last aya marker on page: \(lastWord.surah):\(lastWord.ayah):\(lastWord.position)")
                    }
                }
            }
            return
        }

        // Find the previous verse's ayah marker
        if let lastWord = findPreviousVerseMarker(from: current, in: allWords) {
            // In hidden mode, hide all words from previous verse end to current position
            if isTextHidden {
                hideWordsBetween(from: lastWord, to: current, allWords: allWords)
            }

            selectedWord = lastWord
            unhideWord(lastWord)
            writeLog("⬅️⬅️  Previous verse: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
        } else {
            // No previous verse on this page
            if isTextHidden {
                // Hide words from beginning of page to current verse marker
                guard let currentIndex = allWords.firstIndex(of: current) else { return }

                for index in 0...currentIndex {
                    let wordId = allWords[index]
                    if let wordData = wordDataCache.getWordData(surah: wordId.surah, ayah: wordId.ayah, position: wordId.position) {
                        if !wordData.isHidden {
                            wordData.isHidden = true
                        }
                    }
                }

                do {
                    try modelContext.save()
                    writeLog("🔒 Hid words from beginning to current verse: \(current.surah):\(current.ayah)")
                } catch {
                    writeLog("❌ Error hiding words: \(error)")
                }

                // Set selection to nil
                selectedWord = nil
                writeLog("⬅️⬅️  Previous verse: At start of page, cleared selection")
            } else {
                // Not in hidden mode - go to previous page and select last aya marker
                if currentPage > 1 {
                    isAutoNavigating = true
                    loadNextPageVisible = true

                    // Check if we're in 2-page mode and navigate accordingly
                    if shouldShowTwoPages {
                        currentPage = max(1, currentPage - 2)
                    } else {
                        currentPage -= 1
                    }

                    writeLog("⬅️  Previous page: \(currentPage)")

                    // After page loads, select the last aya marker
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let newPageWords = self.getAllWordsInOrder()
                        if let lastWord = newPageWords.last {
                            self.selectedWord = lastWord
                            self.writeLog("🔘 Selected last aya marker on page: \(lastWord.surah):\(lastWord.ayah):\(lastWord.position)")
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
                    // In hidden mode, unhide all words in the first verse
                    if isTextHidden {
                        // Unhide all words in the first verse (including the first word)
                        for wordId in firstVerseWords {
                            unhideWord(wordId)
                        }
                    }

                    selectedWord = ayahMarker
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
            // In hidden mode, unhide all words from current to verse marker
            if isTextHidden {
                unhideWordsBetween(from: current, to: currentVerseMarker, allWords: allWords)
            }

            selectedWord = currentVerseMarker
            unhideWord(currentVerseMarker)
            writeLog("➡️➡️  Jump to current verse marker: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
            return
        }

        // We're at the ayah marker, so find the next verse's ayah marker
        if let lastWord = findNextVerseMarker(from: current, in: allWords) {
            // In hidden mode, unhide all words from current to next verse marker
            if isTextHidden {
                unhideWordsBetween(from: current, to: lastWord, allWords: allWords)
            }

            selectedWord = lastWord
            unhideWord(lastWord)
            writeLog("➡️➡️  Next verse: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
        } else {
            // No next verse on this page, go to next page (don't select anything - let user guess first)
            if currentPage < 604 {
                // Check if we're in 2-page mode and navigate accordingly
                if shouldShowTwoPages {
                    currentPage = min(603, currentPage + 2)
                } else {
                    currentPage += 1
                }
                selectedWord = nil  // Clear selection
                writeLog("➡️  Next page: \(currentPage) (ready to guess)")
            }
        }
    }

    // Unhide all words between two positions and record reviews
    func unhideWordsBetween(from start: WordIdentifier, to end: WordIdentifier, allWords: [WordIdentifier]) {
        guard let startIndex = allWords.firstIndex(of: start),
              let endIndex = allWords.firstIndex(of: end) else {
            return
        }

        var reviewedCount = 0

        // Unhide all words between start and end (exclusive of start, inclusive of end)
        for index in (startIndex + 1)...endIndex {
            let wordId = allWords[index]
            guard let wordData = wordDataCache.getWordData(
                surah: wordId.surah,
                ayah: wordId.ayah,
                position: wordId.position
            ) else {
                continue
            }

            // Only unhide and record if the word was actually hidden
            if wordData.isHidden {
                wordData.isHidden = false

                // Record interaction (review) for this word
                let interaction = WordInteraction(wordData: wordData)
                wordData.interactions.append(interaction)
                modelContext.insert(interaction)

                reviewedCount += 1
            }
        }

        if reviewedCount > 0 {
            do {
                try modelContext.save()
                writeLog("📚 Quick review: Unhid and recorded \(reviewedCount) words")
            } catch {
                writeLog("❌ Error saving quick review: \(error)")
            }
        }
    }

    // Hide all words between two positions (for practice mode)
    func hideWordsBetween(from start: WordIdentifier, to end: WordIdentifier, allWords: [WordIdentifier]) {
        guard let startIndex = allWords.firstIndex(of: start),
              let endIndex = allWords.firstIndex(of: end) else {
            return
        }

        var hiddenCount = 0

        // Hide all words between start and end (exclusive of start, inclusive of end)
        for index in (startIndex + 1)...endIndex {
            let wordId = allWords[index]
            guard let wordData = wordDataCache.getWordData(
                surah: wordId.surah,
                ayah: wordId.ayah,
                position: wordId.position
            ) else {
                continue
            }

            // Only hide if the word was visible
            if !wordData.isHidden {
                wordData.isHidden = true
                hiddenCount += 1
            }
        }

        if hiddenCount > 0 {
            do {
                try modelContext.save()
                writeLog("🔄 Practice mode: Hid \(hiddenCount) words for re-testing")
            } catch {
                writeLog("❌ Error hiding words: \(error)")
            }
        }
    }

    func previousPage() {
        if currentPage > 1 {
            if shouldShowTwoPages {
                // In 2-page mode, skip by 2 pages (always land on odd page)
                currentPage = max(1, currentPage - 2)
            } else {
                currentPage -= 1
            }

            // In hiding mode, going backward should show the page(s) (because we're reviewing)
            // Use a delay to ensure loadPage() has finished before unhiding
            if isTextHidden {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if self.shouldShowTwoPages {
                        let oddPage = self.currentPage % 2 == 0 ? self.currentPage - 1 : self.currentPage
                        let evenPage = oddPage + 1
                        self.wordDataCache.toggleAllWordsHidden(on: oddPage, hidden: false)
                        if evenPage <= 604 {
                            self.wordDataCache.toggleAllWordsHidden(on: evenPage, hidden: false)
                        }
                        self.writeLog("⬅️  Previous page: \(self.currentPage) (shown for review)")
                    } else {
                        self.wordDataCache.toggleAllWordsHidden(on: self.currentPage, hidden: false)
                        self.writeLog("⬅️  Previous page: \(self.currentPage) (shown for review)")
                    }
                }
            } else {
                writeLog("⬅️  Previous page: \(currentPage)")
            }
        }
    }

    func nextPage() {
        if currentPage < 604 {
            if shouldShowTwoPages {
                // In 2-page mode, skip by 2 pages (always land on odd page)
                currentPage = min(603, currentPage + 2)
            } else {
                currentPage += 1
            }
            writeLog("➡️  Next page: \(currentPage)")
        }
    }

    func jumpToPage() {
        guard let pageNum = Int(pageNumberInput) else {
            // Invalid input - show toast and keep field open
            writeLog("❌ Invalid page number: \(pageNumberInput)")
            showInvalidPageToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showInvalidPageToast = false
                }
            }
            return
        }

        if pageNum >= 1 && pageNum <= 604 {
            // Valid page - navigate and close editor
            currentPage = pageNum
            isEditingPageNumber = false
            pageFieldFocused = false
            writeLog("🔢 Jumped to page: \(currentPage)")
        } else {
            // Out of range - show toast and keep field open
            writeLog("❌ Page number out of range: \(pageNum)")
            showInvalidPageToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showInvalidPageToast = false
                }
            }
        }
    }

    func getWordData(surah: Int, ayah: Int, position: Int) -> WordData? {
        return wordDataCache.getWordData(surah: surah, ayah: ayah, position: position)
    }

    // Calculate minimum width needed to display a page without horizontal scrolling
    func calculateMinimumPageWidth(for pageNumber: Int) -> CGFloat {
        let pageWords = MushafCache.shared.getPageWords(pageNumber)

        // Get the correct font for this specific page
        let pageFontFamily: String
        if useQPCV1 {
            pageFontFamily = "QCF_P\(String(format: "%03d", pageNumber))"
        } else {
            pageFontFamily = fontFamily
        }
        let font = FontUtilities.font(named: pageFontFamily, size: baseFontSize)

        var maxLineWidth: CGFloat = 0

        // Check all 15 lines and find the widest one
        for lineNum in 1...15 {
            guard let words = pageWords[lineNum] else { continue }

            var lineWidth: CGFloat = 0
            for word in words {
                let size = FontUtilities.size(of: word.text, font: font)
                lineWidth += size.width
            }

            maxLineWidth = max(maxLineWidth, lineWidth)
        }

        // Add the ACTUAL page margins from settings
        let pageHorizontalPadding: CGFloat = CGFloat(pageMarginLeft) + CGFloat(pageMarginRight)

        return maxLineWidth + pageHorizontalPadding
    }

    func toggleAllWordsHidden(hidden: Bool) {
        // Use single source of truth to check if we're in 2-page mode
        if shouldShowTwoPages {
            // In 2-page mode, hide/show both pages
            let oddPage = currentPage % 2 == 0 ? currentPage - 1 : currentPage
            let evenPage = oddPage + 1

            wordDataCache.toggleAllWordsHidden(on: oddPage, hidden: hidden)
            if evenPage <= 604 {
                wordDataCache.toggleAllWordsHidden(on: evenPage, hidden: hidden)
            }
            writeLog("👁️ Text \(hidden ? "hidden" : "shown") for pages \(oddPage)-\(evenPage)")
        } else {
            // Single page mode
            wordDataCache.toggleAllWordsHidden(on: currentPage, hidden: hidden)
            writeLog("👁️ Text \(hidden ? "hidden" : "shown") for page \(currentPage)")
        }
    }

    func writeLog(_ message: String) {
        #if os(macOS)
        let logFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("memquran_debug.log")
        #else
        let logFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("memquran_debug.log")
        #endif

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
