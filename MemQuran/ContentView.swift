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

extension WordIdentifier: Comparable {
    static func < (lhs: WordIdentifier, rhs: WordIdentifier) -> Bool {
        if lhs.surah != rhs.surah {
            return lhs.surah < rhs.surah
        }
        if lhs.ayah != rhs.ayah {
            return lhs.ayah < rhs.ayah
        }
        return lhs.position < rhs.position
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
    let pageHidden: Bool  // Page-level hidden state
    let isWordVisible: (WordIdentifier, Bool, WordIdentifier?) -> Bool  // Visibility calculation function
    @Binding var selectedWord: WordIdentifier?
    let anchorWord: WordIdentifier?
    let onWordTap: (WordIdentifier) -> Void
    let onMarkMistake: (WordIdentifier) -> Void
    let onAddBookmark: (WordIdentifier) -> Void
    let onViewNotes: (WordIdentifier) -> Void
    let onResearchWord: (WordIdentifier) -> Void
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
                        pageHidden: pageHidden,
                        isWordVisible: self.isWordVisible,
                        selectedWord: $selectedWord,
                        anchorWord: anchorWord,
                        onWordTap: onWordTap,
                        onMarkMistake: onMarkMistake,
                        onAddBookmark: onAddBookmark,
                        onViewNotes: onViewNotes,
                        onResearchWord: onResearchWord
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
    let pageHidden: Bool  // Page-level hidden state
    let isWordVisible: (WordIdentifier, Bool, WordIdentifier?) -> Bool  // Visibility calculation function
    @Binding var selectedWord: WordIdentifier?
    let anchorWord: WordIdentifier?
    let onWordTap: (WordIdentifier) -> Void
    let onMarkMistake: (WordIdentifier) -> Void
    let onAddBookmark: (WordIdentifier) -> Void
    let onViewNotes: (WordIdentifier) -> Void
    let onResearchWord: (WordIdentifier) -> Void

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
                        let isAnchor = anchorWord == wordId

                        let wordIsVisible = isWordVisible(wordId, pageHidden, selectedWord)
                        Text(quranWord.text)
                            .font(getFont(fontName: fontFamily, size: baseFontSize))
                            .opacity(wordIsVisible ? 1 : 0)
                            .allowsHitTesting(wordIsVisible)  // Pass through touches when hidden
                            .padding(.horizontal, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isAnchor ? Color.red : (isSelected ? Color.blue : Color.clear),
                                            lineWidth: (isAnchor || isSelected) ? 2 : 0)
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

                                Button(action: {
                                    onViewNotes(wordId)
                                }) {
                                    Label("Notes", systemImage: "note.text")
                                }

                                Divider()

                                Button(action: {
                                    onResearchWord(wordId)
                                }) {
                                    Label("Research", systemImage: "book.closed")
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
    @AppStorage("currentPage") private var currentPage: Int = 2  // Start at page 2 (Al-Baqarah)
    @State private var lines: [MushafLine] = []
    @State private var lineWords: [Int: [QuranWord]] = [:]
    @State private var actualDisplayedPage: Int = 1  // The actual page number being displayed (odd in 2-page mode)
    @State private var showingSettings = false
    @State private var selectedWord: WordIdentifier?
    @State private var anchorWord: WordIdentifier? = nil
    @State private var anchorPage: Int? = nil
    @State private var capturedAnchorWord: WordIdentifier? = nil  // Captured at gesture start
    @State private var capturedSelectedWord: WordIdentifier? = nil  // Captured at gesture start
    @State private var capturedAnchorPage: Int? = nil  // Captured at gesture start
    @State private var hasGestureCapturedState = false  // Track if gesture has captured state
    @State private var isAutoNavigating: Bool = false  // Track if we're auto-turning pages
    @State private var showMistakeToast: Bool = false  // Show toast when mistake is marked
    @State private var isEditingPageNumber: Bool = false  // Track if user is editing page number
    @State private var pageNumberInput: String = ""  // User's page number input
    @State private var bookmarkWordToAdd: WordIdentifier?  // Word to bookmark (triggers sheet when set)
    @State private var notesWordToView: WordIdentifier?  // Word to view/edit notes (triggers sheet when set)
    @State private var researchWordToView: WordIdentifier?  // Word to research (triggers sheet when set)
    @State private var showingBookmarksList: Bool = false  // Show bookmarks list
    @State private var showingAudioMode: Bool = false  // Show audio memorization mode
    @State private var windowWidth: CGFloat = 0  // Track window width for 2-page mode calculation
    @State private var linesLeft: [MushafLine] = []  // For even page (left side)
    @State private var lineWordsLeft: [Int: [QuranWord]] = [:]  // For even page (left side)
    @Binding var isTextHidden: Bool
    @FocusState private var pageFieldFocused: Bool
    @State private var showInvalidPageToast: Bool = false

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
        PageModeManager.shared.shouldShowTwoPages(
            currentPage: currentPage,
            windowWidth: windowWidth,
            calculatePageWidth: calculateMinimumPageWidth
        )
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
                                currentPage: actualDisplayedPage + 1,
                                lines: linesLeft,
                                lineWords: lineWordsLeft,
                                fontFamily: useQPCV1 ? "QCF_P\(String(format: "%03d", actualDisplayedPage + 1))" : fontFamily,
                                baseFontSize: baseFontSize,
                                lineHeight: lineHeight,
                                lineSpacing: lineSpacing,
                                wordSpacing: wordSpacing,
                                useQPCV1: useQPCV1,
                                getWordData: getWordData,
                                pageHidden: isTextHidden,
                                isWordVisible: isWordVisible,
                                selectedWord: $selectedWord,
                                anchorWord: anchorWord,
                                onWordTap: handleWordTap,
                                onMarkMistake: handleMarkMistake,
                                onAddBookmark: handleAddBookmark,
                                onViewNotes: handleViewNotes,
                                onResearchWord: handleResearchWord,
                                showPageBorder: showPageBorder,
                                marginTop: CGFloat(pageMarginTop),
                                marginBottom: CGFloat(pageMarginBottom),
                                marginLeft: CGFloat(pageMarginLeft),
                                marginRight: CGFloat(pageMarginRight)
                            )
                            .frame(width: windowWidth / 2)

                            // Odd page on RIGHT
                            PageContentView(
                                currentPage: actualDisplayedPage,
                                lines: lines,
                                lineWords: lineWords,
                                fontFamily: useQPCV1 ? "QCF_P\(String(format: "%03d", actualDisplayedPage))" : fontFamily,
                                baseFontSize: baseFontSize,
                                lineHeight: lineHeight,
                                lineSpacing: lineSpacing,
                                wordSpacing: wordSpacing,
                                useQPCV1: useQPCV1,
                                getWordData: getWordData,
                                pageHidden: isTextHidden,
                                isWordVisible: isWordVisible,
                                selectedWord: $selectedWord,
                                anchorWord: anchorWord,
                                onWordTap: handleWordTap,
                                onMarkMistake: handleMarkMistake,
                                onAddBookmark: handleAddBookmark,
                                onViewNotes: handleViewNotes,
                                onResearchWord: handleResearchWord,
                                showPageBorder: showPageBorder,
                                marginTop: CGFloat(pageMarginTop),
                                marginBottom: CGFloat(pageMarginBottom),
                                marginLeft: CGFloat(pageMarginLeft),
                                marginRight: CGFloat(pageMarginRight)
                            )
                            .frame(width: windowWidth / 2)
                        } else {
                            // Single page mode
                            PageContentView(
                                currentPage: actualDisplayedPage,
                                lines: lines,
                                lineWords: lineWords,
                                fontFamily: useQPCV1 ? "QCF_P\(String(format: "%03d", actualDisplayedPage))" : fontFamily,
                                baseFontSize: baseFontSize,
                                lineHeight: lineHeight,
                                lineSpacing: lineSpacing,
                                wordSpacing: wordSpacing,
                                useQPCV1: useQPCV1,
                                getWordData: getWordData,
                                pageHidden: isTextHidden,
                                isWordVisible: isWordVisible,
                                selectedWord: $selectedWord,
                                anchorWord: anchorWord,
                                onWordTap: handleWordTap,
                                onMarkMistake: handleMarkMistake,
                                onAddBookmark: handleAddBookmark,
                                onViewNotes: handleViewNotes,
                                onResearchWord: handleResearchWord,
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
                            .onChanged { value in
                                // Capture state on first change to prevent race conditions
                                if !hasGestureCapturedState {
                                    capturedAnchorWord = anchorWord
                                    capturedSelectedWord = selectedWord
                                    capturedAnchorPage = anchorPage
                                    hasGestureCapturedState = true
                                    let anchorStr = anchorWord?.id ?? "nil"
                                    let selectedStr = selectedWord?.id ?? "nil"
                                    let pageStr = anchorPage?.description ?? "nil"
                                    print("🎬 GESTURE START: captured anchor=\(anchorStr) selected=\(selectedStr) page=\(pageStr)")
                                    writeLog("🎬 GESTURE START: captured anchor=\(anchorStr) selected=\(selectedStr) page=\(pageStr)")
                                }
                            }
                            .onEnded { value in
                                defer { hasGestureCapturedState = false }  // Reset for next gesture

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
                                        // Vertical swipes - use CAPTURED state to prevent race conditions
                                        if value.translation.height < 0 {
                                            // Up swipe
                                            print("⬆️ UP SWIPE: capturedAnchor=\(capturedAnchorWord?.id ?? "nil") capturedSelected=\(capturedSelectedWord?.id ?? "nil")")

                                            // DEBUG: Check condition components
                                            let anchorNotNil = capturedAnchorWord != nil
                                            let selectedIsNil = capturedSelectedWord == nil
                                            print("🔍 DEBUG: anchorNotNil=\(anchorNotNil) selectedIsNil=\(selectedIsNil) combined=\(anchorNotNil && selectedIsNil)")

                                            // Handle nil selector case - if anchor exists and no current position, jump to it
                                            if let anchor = capturedAnchorWord, let aPage = capturedAnchorPage, capturedSelectedWord == nil {
                                                // Get first word on current page to compare with anchor
                                                if let firstWord = getFirstWordOnPage(currentPage) {
                                                    // Only jump if anchor is above (less than first word on page)
                                                    if anchor < firstWord {
                                                        print("⬆️ Swipe up -> jump to anchor (nil selector, anchor above) anchor=\(anchor.id)")
                                                        writeLog("⬆️ Swipe up -> jump to anchor (nil selector, anchor above) anchor=\(anchor.id)")
                                                        jumpToAnchor(to: anchor, onPage: capturedAnchorPage)
                                                    } else {
                                                        print("⬆️ Swipe up -> previous verse (nil selector, anchor not above)")
                                                        writeLog("⬆️ Swipe up -> previous verse (nil selector, anchor not above)")
                                                        previousVerse()
                                                    }
                                                } else {
                                                    // Can't get first word, do normal navigation
                                                    print("⬆️ Swipe up -> previous verse (nil selector, no first word)")
                                                    writeLog("⬆️ Swipe up -> previous verse (nil selector, no first word)")
                                                    previousVerse()
                                                }
                                            }
                                            // Handle normal case with both anchor and selector
                                            else if let anchor = capturedAnchorWord, let selected = capturedSelectedWord {
                                                print("⬆️ Comparing: anchor=\(anchor.id) selected=\(selected.id) anchor<selected=\(anchor < selected)")

                                                // Check if selected word is at top of page
                                                let atTopBoundary = isAtPageBoundary(word: selected, boundary: .top)
                                                print("⬆️ Selected word at top boundary: \(atTopBoundary)")

                                                if atTopBoundary {
                                                    // At top of page - check if anchor is above before deciding to navigate
                                                    if anchor < selected {
                                                        // Anchor above - jump to it instead of navigating
                                                        print("⬆️ Swipe up -> jump to anchor (at top boundary, anchor above) anchor=\(anchor.id) selected=\(selected.id)")
                                                        writeLog("⬆️ Swipe up -> jump to anchor (at top boundary, anchor above) anchor=\(anchor.id) selected=\(selected.id)")
                                                        jumpToAnchor(to: capturedAnchorWord, onPage: capturedAnchorPage)
                                                    } else {
                                                        // No anchor above - navigate to previous page
                                                        print("⬆️ Swipe up -> previous verse (at top boundary, no anchor above)")
                                                        writeLog("⬆️ Swipe up -> previous verse (at top boundary, no anchor above)")
                                                        previousVerse()
                                                    }
                                                } else if anchor < selected {
                                                    // Not at top boundary and anchor is above - jump to it
                                                    print("⬆️ Swipe up -> jump to anchor (above) anchor=\(anchor.id) selected=\(selected.id)")
                                                    writeLog("⬆️ Swipe up -> jump to anchor (above) anchor=\(anchor.id) selected=\(selected.id)")
                                                    jumpToAnchor(to: capturedAnchorWord, onPage: capturedAnchorPage)
                                                } else {
                                                    // Anchor below - normal navigation
                                                    print("⬆️ Swipe up -> previous verse (anchor below)")
                                                    writeLog("⬆️ Swipe up -> previous verse (anchor below)")
                                                    previousVerse()
                                                }
                                            } else {
                                                // No anchor - normal navigation
                                                print("⬆️ Swipe up -> previous verse")
                                                writeLog("⬆️ Swipe up -> previous verse")
                                                previousVerse()
                                            }
                                        } else {
                                            // Down swipe
                                            print("⬇️ DOWN SWIPE: capturedAnchor=\(capturedAnchorWord?.id ?? "nil") capturedSelected=\(capturedSelectedWord?.id ?? "nil")")

                                            // DEBUG: Check condition components
                                            let anchorNotNil = capturedAnchorWord != nil
                                            let selectedIsNil = capturedSelectedWord == nil
                                            print("🔍 DEBUG: anchorNotNil=\(anchorNotNil) selectedIsNil=\(selectedIsNil) combined=\(anchorNotNil && selectedIsNil)")

                                            // Handle nil selector case - if anchor exists and no current position, jump to it
                                            if let anchor = capturedAnchorWord, let aPage = capturedAnchorPage, capturedSelectedWord == nil {
                                                // Get first word on current page to compare with anchor
                                                if let firstWord = getFirstWordOnPage(currentPage) {
                                                    // Only jump if anchor is below (greater than first word on page)
                                                    if anchor > firstWord {
                                                        print("⬇️ Swipe down -> jump to anchor (nil selector, anchor below) anchor=\(anchor.id)")
                                                        writeLog("⬇️ Swipe down -> jump to anchor (nil selector, anchor below) anchor=\(anchor.id)")
                                                        jumpToAnchor(to: anchor, onPage: capturedAnchorPage)
                                                    } else {
                                                        print("⬇️ Swipe down -> next verse (nil selector, anchor not below)")
                                                        writeLog("⬇️ Swipe down -> next verse (nil selector, anchor not below)")
                                                        nextVerse()
                                                    }
                                                } else {
                                                    // Can't get first word, do normal navigation
                                                    print("⬇️ Swipe down -> next verse (nil selector, no first word)")
                                                    writeLog("⬇️ Swipe down -> next verse (nil selector, no first word)")
                                                    nextVerse()
                                                }
                                            }
                                            // Handle normal case with both anchor and selector
                                            else if let anchor = capturedAnchorWord, let selected = capturedSelectedWord {
                                                print("⬇️ Comparing: anchor=\(anchor.id) selected=\(selected.id) anchor>selected=\(anchor > selected)")

                                                // Check if selected word is at bottom of page
                                                let atBottomBoundary = isAtPageBoundary(word: selected, boundary: .bottom)
                                                print("⬇️ Selected word at bottom boundary: \(atBottomBoundary)")

                                                if atBottomBoundary {
                                                    // At bottom of page - always navigate to next page
                                                    print("⬇️ Swipe down -> next verse (at bottom boundary)")
                                                    writeLog("⬇️ Swipe down -> next verse (at bottom boundary)")
                                                    nextVerse()
                                                } else if anchor > selected {
                                                    // Not at bottom boundary and anchor is below - jump to it
                                                    print("⬇️ Swipe down -> jump to anchor (below) anchor=\(anchor.id) selected=\(selected.id)")
                                                    writeLog("⬇️ Swipe down -> jump to anchor (below) anchor=\(anchor.id) selected=\(selected.id)")
                                                    jumpToAnchor(to: capturedAnchorWord, onPage: capturedAnchorPage)
                                                } else {
                                                    // Anchor above - normal navigation
                                                    print("⬇️ Swipe down -> next verse (anchor above)")
                                                    writeLog("⬇️ Swipe down -> next verse (anchor above)")
                                                    nextVerse()
                                                }
                                            } else {
                                                // No anchor - normal navigation
                                                print("⬇️ Swipe down -> next verse")
                                                writeLog("⬇️ Swipe down -> next verse")
                                                nextVerse()
                                            }
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
                            .onChange(of: isEditingPageNumber) { oldValue, newValue in
                                // When entering edit mode, ensure focus is set
                                if newValue {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        pageFieldFocused = true
                                    }
                                }
                            }
                            .onAppear {
                                pageNumberInput = "\(currentPage)"
                                // Delay focus to ensure TextField is fully rendered
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    pageFieldFocused = true
                                    // Auto-select text after focus is set
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        #if os(iOS)
                                        UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                        #endif
                                    }
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
            loadPage(newValue)
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
            // Check for anchor navigation in memorization mode (same logic as swipe up)
            if isTextHidden {
                // Handle nil selector case - if anchor exists and no current position, jump to it
                if let anchor = anchorWord, selectedWord == nil {
                    print("⬆️ Arrow up -> jump to anchor (nil selector) anchor=\(anchor.id)")
                    writeLog("⬆️ Arrow up -> jump to anchor (nil selector) anchor=\(anchor.id)")
                    jumpToAnchor(to: anchor, onPage: anchorPage)
                }
                // Handle normal case with both anchor and selector
                else if let anchor = anchorWord, let selected = selectedWord {
                    print("⬆️ Arrow up: anchor=\(anchor.id) selected=\(selected.id) anchor<selected=\(anchor < selected)")

                    // Check if selected word is at top of page
                    let atTopBoundary = isAtPageBoundary(word: selected, boundary: .top)
                    print("⬆️ Selected word at top boundary: \(atTopBoundary)")

                    if atTopBoundary {
                        // At top of page - always navigate to previous page
                        print("⬆️ Arrow up -> previous verse (at top boundary)")
                        writeLog("⬆️ Arrow up -> previous verse (at top boundary)")
                        previousVerse()
                    } else if anchor < selected {
                        // Not at top boundary and anchor is above - jump to it
                        print("⬆️ Arrow up -> jump to anchor (above) anchor=\(anchor.id) selected=\(selected.id)")
                        writeLog("⬆️ Arrow up -> jump to anchor (above) anchor=\(anchor.id) selected=\(selected.id)")
                        jumpToAnchor(to: anchorWord, onPage: anchorPage)
                    } else {
                        // Anchor below - normal navigation
                        print("⬆️ Arrow up -> previous verse (anchor below)")
                        writeLog("⬆️ Arrow up -> previous verse (anchor below)")
                        previousVerse()
                    }
                } else {
                    // No anchor - normal navigation
                    previousVerse()
                }
            } else {
                // Not in memorization mode - normal navigation
                previousVerse()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextVerse)) { _ in
            // Check for anchor navigation in memorization mode (same logic as swipe down)
            if isTextHidden {
                // Handle nil selector case - if anchor exists and no current position, jump to it
                if let anchor = anchorWord, selectedWord == nil {
                    print("⬇️ Arrow down -> jump to anchor (nil selector) anchor=\(anchor.id)")
                    writeLog("⬇️ Arrow down -> jump to anchor (nil selector) anchor=\(anchor.id)")
                    jumpToAnchor(to: anchor, onPage: anchorPage)
                }
                // Handle normal case with both anchor and selector
                else if let anchor = anchorWord, let selected = selectedWord {
                    print("⬇️ Arrow down: anchor=\(anchor.id) selected=\(selected.id) anchor>selected=\(anchor > selected)")

                    // Check if selected word is at bottom of page
                    let atBottomBoundary = isAtPageBoundary(word: selected, boundary: .bottom)
                    print("⬇️ Selected word at bottom boundary: \(atBottomBoundary)")

                    if atBottomBoundary {
                        // At bottom of page - always navigate to next page
                        print("⬇️ Arrow down -> next verse (at bottom boundary)")
                        writeLog("⬇️ Arrow down -> next verse (at bottom boundary)")
                        nextVerse()
                    } else if anchor > selected {
                        // Not at bottom boundary and anchor is below - jump to it
                        print("⬇️ Arrow down -> jump to anchor (below) anchor=\(anchor.id) selected=\(selected.id)")
                        writeLog("⬇️ Arrow down -> jump to anchor (below) anchor=\(anchor.id) selected=\(selected.id)")
                        jumpToAnchor(to: anchorWord, onPage: anchorPage)
                    } else {
                        // Anchor above - normal navigation
                        print("⬇️ Arrow down -> next verse (anchor above)")
                        writeLog("⬇️ Arrow down -> next verse (anchor above)")
                        nextVerse()
                    }
                } else {
                    // No anchor - normal navigation
                    nextVerse()
                }
            } else {
                // Not in memorization mode - normal navigation
                nextVerse()
            }
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
            AddBookmarkView(wordId: wordId)
        }
        .sheet(item: $notesWordToView) { wordId in
            WordNotesView(wordId: wordId)
        }
        .sheet(item: $researchWordToView) { wordId in
            WordResearchView(wordId: wordId)
        }
        .sheet(isPresented: $showingBookmarksList) {
            BookmarksView(onBookmarkSelected: jumpToBookmark, onErrorSelected: jumpToError)
        }
        .sheet(isPresented: $showingAudioMode) {
            // Get page words for the current page
            // Use already-loaded lineWords data
            let pageWords = self.lineWords
            let pageWordsArray = pageWords
                .sorted { $0.key < $1.key }
                .map { (line: $0.key, words: $0.value) }

            AudioMemorizationView(
                currentPage: $currentPage,
                pageWords: pageWordsArray,
                onPageAdvance: { nextPage in
                    // For next page advance, we'll need to load data asynchronously
                    // Return empty data for now - AudioMemorizationView should handle async loading
                    return []
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

    func loadPage(_ pageNumber: Int, selectWord: WordIdentifier? = nil) {
        Task {
            await loadPageAsync(pageNumber, selectWord: selectWord)
        }
    }

    private func loadPageAsync(_ pageNumber: Int, selectWord: WordIdentifier? = nil) async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Clear selection when changing pages (unless auto-navigating or selectWord is provided)
        if !isAutoNavigating && selectWord == nil {
            selectedWord = nil
        }
        isAutoNavigating = false  // Reset flag

        // In 2-page mode, ensure we always have an odd page number
        // In single-page mode, use the page number as-is
        let actualPage: Int
        if shouldShowTwoPages {
            actualPage = pageNumber % 2 == 0 ? pageNumber - 1 : pageNumber
        } else {
            actualPage = pageNumber
        }
        let evenPage = actualPage + 1

        // Store the actual page being displayed so the view uses correct page numbers
        actualDisplayedPage = actualPage

        // CRITICAL: Load fonts BEFORE loading page data to prevent rendering issues
        FontLoader.shared.ensureFontLoaded(forPage: actualPage)
        if shouldShowTwoPages && evenPage <= 604 {
            FontLoader.shared.ensureFontLoaded(forPage: evenPage)
        }

        // Load current page
        await MushafCache.shared.ensureCurrentPageLoaded(actualPage)
        if shouldShowTwoPages && evenPage <= 604 {
            await MushafCache.shared.ensureCurrentPageLoaded(evenPage)
        }

        // Load surrounding pages asynchronously (doesn't block UI)
        Task.detached(priority: .userInitiated) {
            await MushafCache.shared.ensurePagesLoaded(around: actualPage, range: 5)
        }

        // Preload fonts for surrounding pages in background
        FontLoader.shared.preloadSurroundingPages(around: actualPage, range: 5)

        // Load the main page
        lines = MushafCache.shared.getLinesForPage(actualPage)
        lineWords = await MushafCache.shared.getPageWords(actualPage)
        print("📄 Loading page data for page \(actualPage), got \(lines.count) lines")

        // If in 2-page mode and not at the last page, also load the even page (left side)
        if shouldShowTwoPages && evenPage <= 604 {
            linesLeft = MushafCache.shared.getLinesForPage(evenPage)
            lineWordsLeft = await MushafCache.shared.getPageWords(evenPage)

            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            writeLog("📄 Loaded pages \(actualPage)-\(evenPage) in \(String(format: "%.2f", elapsed))ms (mode: \(isTextHidden ? "hidden" : "visible"))")
        } else {
            // Single page mode
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            writeLog("📄 Loaded page \(actualPage) in \(String(format: "%.2f", elapsed))ms (mode: \(isTextHidden ? "hidden" : "visible"))")
        }

        // Set selection if specified
        if let targetWord = selectWord {
            selectedWord = targetWord
            writeLog("🔘 Auto-selected word: \(targetWord.surah):\(targetWord.ayah):\(targetWord.position)")
        }

        // Check if anchor is still in scope after page change
        checkAndRemoveAnchorIfNeeded()
    }

    func handleWordTap(_ wordId: WordIdentifier) {
        // Tapping any word sets it as anchor (or toggles selection in visible mode)
        if !isTextHidden {
            // Normal mode behavior
            if selectedWord == wordId {
                selectedWord = nil
            } else {
                selectedWord = wordId
                unhideWord(wordId)
            }
            return
        }

        if isTextHidden {
            // Tapping anchor removes it
            if anchorWord == wordId {
                writeLog("🔴 Removed anchor (tapped anchor)")
                anchorWord = nil
                anchorPage = nil
                return
            }

            // Tapping any other word sets/moves anchor
            if isWordVisible(wordId: wordId, pageHidden: isTextHidden, selectedWord: selectedWord) {
                anchorWord = wordId
                anchorPage = currentPage
                writeLog("📍 Set anchor: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
                return
            }
        }
    }

    func unhideWord(_ wordId: WordIdentifier) {
        guard let wordData = getOrCreateWordData(surah: wordId.surah, ayah: wordId.ayah, position: wordId.position) else {
            return
        }

        // Record interaction (review) when word is revealed
        writeLog("👁️ Revealed word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")

        let interaction = WordInteraction(wordData: wordData)
        if wordData.interactions == nil {
            wordData.interactions = []
        }
        wordData.interactions?.append(interaction)
        modelContext.insert(interaction)

        do {
            try modelContext.save()
            writeLog("📊 Review recorded for word: \(wordId.surah):\(wordId.ayah):\(wordId.position) (total reviews: \(wordData.interactions?.count ?? 0))")
        } catch {
            writeLog("❌ Error saving interaction: \(error)")
        }
    }

    func markMistake() {
        guard let current = selectedWord else {
            writeLog("❌ No word selected to mark mistake")
            return
        }

        guard let wordData = getOrCreateWordData(surah: current.surah, ayah: current.ayah, position: current.position) else {
            writeLog("❌ Could not find word data for: \(current.surah):\(current.ayah):\(current.position)")
            return
        }

        let mistake = WordMistake(wordData: wordData)
        if wordData.mistakes == nil {
            wordData.mistakes = []
        }
        wordData.mistakes?.append(mistake)
        modelContext.insert(mistake)

        do {
            try modelContext.save()
            writeLog("❌ Mistake marked for word: \(current.surah):\(current.ayah):\(current.position) (total: \(wordData.mistakes?.count ?? 0))")

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

    func handleViewNotes(_ wordId: WordIdentifier) {
        selectedWord = wordId
        notesWordToView = wordId
        writeLog("📝 Opening notes for word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
    }

    func handleResearchWord(_ wordId: WordIdentifier) {
        selectedWord = wordId
        researchWordToView = wordId
        writeLog("📚 Opening research for word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
    }

    func jumpToError(_ wordId: WordIdentifier) {
        Task {
            await jumpToErrorAsync(wordId)
        }
    }

    private func jumpToErrorAsync(_ wordId: WordIdentifier) async {
        writeLog("❌ Jumping to error word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")

        // Find the error word's page efficiently using database query (ONE query instead of looping 604 pages)
        guard let errorPage = await MushafDatabase.shared.getPageForWord(
            surah: wordId.surah,
            ayah: wordId.ayah,
            position: wordId.position
        ) else {
            writeLog("❌ Could not find page for error word: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
            return
        }

        writeLog("📖 Found error word on page \(errorPage)")

        // Load words from the error page and 1-2 pages before
        // This ensures we can find the previous verse even if it's on a previous page
        let startPage = max(1, errorPage - 2)  // Load up to 2 pages before
        let endPage = errorPage

        var allWords: [(page: Int, word: QuranWord)] = []  // Track which page each word is on

        for page in startPage...endPage {
            let pageWords = await MushafCache.shared.getPageWords(page)

            for lineNum in 1...15 {
                if let words = pageWords[lineNum] {
                    for word in words {
                        allWords.append((page: page, word: word))
                    }
                }
            }
        }

        // Find the error word in the loaded words
        guard let errorWordIndex = allWords.firstIndex(where: {
            $0.word.surah == wordId.surah &&
            $0.word.ayah == wordId.ayah &&
            $0.word.word == wordId.position
        }) else {
            writeLog("❌ Could not find error word in loaded pages: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
            return
        }

        let errorWord = allWords[errorWordIndex].word

        // Find previous verse's last word
        var targetWord: QuranWord? = nil
        var targetPage: Int? = nil

        // Search backwards for previous verse's last word
        for i in (0..<errorWordIndex).reversed() {
            let word = allWords[i].word
            let page = allWords[i].page

            // If we find a word from the previous ayah, this is it
            if word.surah == errorWord.surah && word.ayah == errorWord.ayah - 1 {
                targetWord = word
                targetPage = page
                break
            } else if word.surah < errorWord.surah {
                // Found previous surah's last ayah
                targetWord = word
                targetPage = page
                break
            } else if word.surah == errorWord.surah && word.ayah < errorWord.ayah - 1 {
                // Went too far back, no previous verse found
                break
            }
        }

        // If we found a target word
        if let target = targetWord, let page = targetPage {
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
            currentPage = errorPage
            writeLog("📖 Navigated to page \(errorPage)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.selectedWord = wordId
                self.unhideWord(wordId)
                self.writeLog("✅ Selected error word (first verse): \(wordId.surah):\(wordId.ayah):\(wordId.position)")
            }
            return
        }
    }

    // Helper function to unhide all verses before the error verse and hide the error verse and after
    func unhideVersesBeforeError(targetPage: Int, errorWord: QuranWord) {
        Task {
            await unhideVersesBeforeErrorAsync(targetPage: targetPage, errorWord: errorWord)
        }
    }

    private func unhideVersesBeforeErrorAsync(targetPage: Int, errorWord: QuranWord) async {
        writeLog("👁️ Unhiding verses before error: \(errorWord.surah):\(errorWord.ayah)")

        // Get all words on the target page
        let pageWords = await MushafCache.shared.getPageWords(targetPage)
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
            // Visibility is now calculated from selection position
            // No need to manually hide/unhide words or fetch WordData here
        }
    }

    func jumpToBookmark(_ wordId: WordIdentifier) {
        Task {
            await jumpToBookmarkAsync(wordId)
        }
    }

    private func jumpToBookmarkAsync(_ wordId: WordIdentifier) async {
        writeLog("📑 Jumping to bookmark: \(wordId.surah):\(wordId.ayah):\(wordId.position)")

        // Query database directly for the page number
        guard let page = await MushafDatabase.shared.getPageForWord(
            surah: wordId.surah,
            ayah: wordId.ayah,
            position: wordId.position
        ) else {
            writeLog("❌ Could not find page for bookmark: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
            return
        }

        // In 2-page mode, adjust to show the correct page pair
        let displayPage: Int
        if shouldShowTwoPages {
            // Ensure we land on an odd page so both pages in the pair are visible
            displayPage = page % 2 == 0 ? page - 1 : page
        } else {
            displayPage = page
        }

        // Navigate to the page
        isAutoNavigating = true
        currentPage = displayPage
        writeLog("📖 Navigated to page \(displayPage)")

        // Select the word after page loads and sheet dismisses
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.selectedWord = wordId
            self.unhideWord(wordId)
            self.writeLog("✅ Selected bookmark: \(wordId.surah):\(wordId.ayah):\(wordId.position)")
        }
    }

    func jumpToAnchor(to anchor: WordIdentifier? = nil, onPage targetPage: Int? = nil) {
        // Use provided parameters or fall back to instance variables
        let actualAnchor = anchor ?? anchorWord
        let actualTargetPage = targetPage ?? anchorPage

        print("🎯 jumpToAnchor() called: anchor=\(actualAnchor?.id ?? "nil") targetPage=\(actualTargetPage?.description ?? "nil")")
        guard let anchor = actualAnchor, let targetPage = actualTargetPage else {
            print("🎯 jumpToAnchor() EARLY RETURN: anchor or targetPage is nil!")
            return
        }

        print("🎯 Jumping to anchor: \(anchor.surah):\(anchor.ayah):\(anchor.position) on page \(targetPage)")
        writeLog("🎯 Jumping to anchor: \(anchor.surah):\(anchor.ayah):\(anchor.position) on page \(targetPage)")

        // Handle cross-page navigation
        if targetPage != currentPage {
            isAutoNavigating = true
            currentPage = targetPage

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.selectedWord = anchor
                // Always use scope check, never clear anchor just because of nil selector
                self.checkAndRemoveAnchorIfNeeded()
            }
        } else {
            selectedWord = anchor
            // Always use scope check, never clear anchor just because of nil selector
            checkAndRemoveAnchorIfNeeded()
        }
    }

    func checkAndRemoveAnchorIfNeeded() {
        guard let anchor = anchorWord, let aPage = anchorPage else { return }

        // Scope: current page +/- 1 (changed from 3 to 1)
        let inScope = abs(currentPage - aPage) <= 1

        // In 2-page mode, also check actualDisplayedPage
        let inScope2Page = shouldShowTwoPages ? abs(actualDisplayedPage - aPage) <= 1 : true

        if !inScope || !inScope2Page {
            print("🗑️ Removing anchor - out of scope (distance: \(abs(currentPage - aPage)))")
            writeLog("🔴 Anchor out of scope (more than 1 page away) - removing")
            anchorWord = nil
            anchorPage = nil
        }
    }

    // Helper function to find which line a word is on
    func getLineNumber(for wordId: WordIdentifier) -> Int? {
        // Check in both lineWords (right/single page) and lineWordsLeft (left page in 2-page mode)
        for (lineNum, words) in lineWords {
            if words.contains(where: { $0.surah == wordId.surah && $0.ayah == wordId.ayah && $0.word == wordId.position }) {
                return lineNum
            }
        }

        // Also check left page in 2-page mode
        if shouldShowTwoPages {
            for (lineNum, words) in lineWordsLeft {
                if words.contains(where: { $0.surah == wordId.surah && $0.ayah == wordId.ayah && $0.word == wordId.position }) {
                    return lineNum
                }
            }
        }

        return nil
    }

    // Helper function to check if a word is at the top or bottom boundary of the page
    // Top boundary: first 2 lines (lines 1-2)
    // Bottom boundary: last 2 lines (lines 14-15)
    func isAtPageBoundary(word: WordIdentifier?, boundary: PageBoundary) -> Bool {
        guard let word = word, let lineNum = getLineNumber(for: word) else {
            return false
        }

        switch boundary {
        case .top:
            return lineNum <= 2
        case .bottom:
            return lineNum >= 14
        }
    }

    // Enum for page boundaries
    enum PageBoundary {
        case top
        case bottom
    }

    // Get all words on current page(s) in order
    func getWordsForPage(_ pageNumber: Int) async -> [WordIdentifier] {
        var allWords: [WordIdentifier] = []

        // Ensure the page is loaded in cache before fetching words
        await MushafCache.shared.ensureCurrentPageLoaded(pageNumber)

        let pageWords = await MushafCache.shared.getPageWords(pageNumber)

        // Sort by line number, then position in line
        let sortedLines = pageWords.keys.sorted()
        for lineNum in sortedLines {
            if let words = pageWords[lineNum] {
                for word in words {
                    allWords.append(WordIdentifier(surah: word.surah, ayah: word.ayah, position: word.word))
                }
            }
        }
        return allWords
    }

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

    // Get the first word on a specific page (synchronous, uses already-loaded data)
    func getFirstWordOnPage(_ pageNumber: Int) -> WordIdentifier? {
        // Use already-loaded lineWords data if available
        let pageWords: [Int: [QuranWord]]
        if pageNumber == currentPage {
            pageWords = lineWords
        } else if pageNumber == currentPage + 1 && shouldShowTwoPages {
            pageWords = lineWordsLeft
        } else {
            // Data not loaded yet
            return nil
        }

        // Get words in order from lineWords
        let sortedLines = pageWords.keys.sorted()
        for lineNum in sortedLines {
            if let words = pageWords[lineNum], let firstWord = words.first {
                return WordIdentifier(surah: firstWord.surah, ayah: firstWord.ayah, position: firstWord.word)
            }
        }
        return nil
    }

    // Async version that fetches from database
    func getFirstWordOnPageAsync(_ pageNumber: Int) async -> WordIdentifier? {
        let words = await getWordsForPage(pageNumber)
        return words.first
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
        Task {
            await previousWordAsync()
        }
    }

    private func previousWordAsync() async {
        // If nothing is selected, go to previous page and select last word
        guard let current = selectedWord else {
            if currentPage > 1 {
                isAutoNavigating = true

                // Calculate target page
                let targetPage: Int
                if shouldShowTwoPages {
                    targetPage = max(1, currentPage - 2)
                } else {
                    targetPage = currentPage - 1
                }

                // Get last word from target page BEFORE changing page
                writeLog("📄 Fetching words from target page \(targetPage) before navigation")
                let targetPageWords = await getWordsForPage(targetPage)
                let wordToSelect = targetPageWords.last
                writeLog("📄 Found \(targetPageWords.count) words on page \(targetPage)")

                currentPage = targetPage
                writeLog("⬅️  Previous page: \(currentPage)")

                // Set selection immediately after page loads
                if let word = wordToSelect {
                    selectedWord = word
                    writeLog("🔘 Selected last word on page: \(word.surah):\(word.ayah):\(word.position)")
                } else {
                    writeLog("⚠️ No words found to select on page \(targetPage)")
                }
            }
            return
        }

        let allWords = getAllWordsInOrder()
        if let currentIndex = allWords.firstIndex(of: current) {
            if currentIndex > 0 {
                let previousWordId = allWords[currentIndex - 1]

                // Move to previous word on same page (visibility calculated from selection)
                selectedWord = previousWordId
                unhideWord(previousWordId)
                writeLog("⬅️  Previous word: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
            } else {
                // At first word on page
                if isTextHidden {
                    // Set selection to nil (visibility calculated from selection)
                    selectedWord = nil
                    writeLog("⬅️  Previous word: At start of page, cleared selection")
                } else {
                    // Not in hidden mode - go to previous page and select last word
                    if currentPage > 1 {
                        isAutoNavigating = true

                        // Calculate target page
                        let targetPage: Int
                        if shouldShowTwoPages {
                            targetPage = max(1, currentPage - 2)
                        } else {
                            targetPage = currentPage - 1
                        }

                        // Get last word from target page BEFORE changing page
                        let targetPageWords = await getWordsForPage(targetPage)
                        let wordToSelect = targetPageWords.last

                        currentPage = targetPage
                        writeLog("⬅️  Previous page: \(currentPage)")

                        // Set selection immediately after page loads
                        if let word = wordToSelect {
                            selectedWord = word
                            writeLog("🔘 Selected last word on page: \(word.surah):\(word.ayah):\(word.position)")
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

    // Calculate if a word should be visible based on page state and selection
    func isWordVisible(wordId: WordIdentifier, pageHidden: Bool, selectedWord: WordIdentifier?) -> Bool {
        // If not in hidden mode, everything is visible
        if !pageHidden {
            return true
        }

        // If no selection, everything is hidden
        guard let selected = selectedWord else {
            return false
        }

        // Word is visible if it comes before or at the selected word
        // Compare: surah, then ayah, then position
        if wordId.surah < selected.surah {
            return true
        } else if wordId.surah == selected.surah {
            if wordId.ayah < selected.ayah {
                return true
            } else if wordId.ayah == selected.ayah {
                return wordId.position <= selected.position
            }
        }

        return false
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
        Task {
            await previousVerseAsync()
        }
    }

    private func previousVerseAsync() async {
        let allWords = getAllWordsInOrder()

        // If nothing is selected, go to previous page and select last aya marker
        guard let current = selectedWord else {
            if currentPage > 1 {
                isAutoNavigating = true

                // Calculate target page
                let targetPage: Int
                if shouldShowTwoPages {
                    targetPage = max(1, currentPage - 2)
                } else {
                    targetPage = currentPage - 1
                }

                // Get last word from target page BEFORE changing page
                let targetPageWords = await getWordsForPage(targetPage)
                let wordToSelect = targetPageWords.last

                currentPage = targetPage
                writeLog("⬅️  Previous page: \(currentPage)")

                // Set selection immediately after page loads
                if let word = wordToSelect {
                    selectedWord = word
                    writeLog("🔘 Selected last aya marker on page: \(word.surah):\(word.ayah):\(word.position)")
                }
            }
            return
        }

        // Find the previous verse's ayah marker
        if let lastWord = findPreviousVerseMarker(from: current, in: allWords) {
            selectedWord = lastWord
            unhideWord(lastWord)
            writeLog("⬅️⬅️  Previous verse: \(selectedWord!.surah):\(selectedWord!.ayah):\(selectedWord!.position)")
        } else {
            // No previous verse on this page
            if isTextHidden {
                // Set selection to nil (visibility calculated from selection)
                selectedWord = nil
                writeLog("⬅️⬅️  Previous verse: At start of page, cleared selection")
            } else {
                // Not in hidden mode - go to previous page and select last aya marker
                if currentPage > 1 {
                    isAutoNavigating = true

                    // Calculate target page
                    let targetPage: Int
                    if shouldShowTwoPages {
                        targetPage = max(1, currentPage - 2)
                    } else {
                        targetPage = currentPage - 1
                    }

                    // Get last word from target page BEFORE changing page
                    writeLog("📄 Fetching words from target page \(targetPage) before navigation")
                    let targetPageWords = await getWordsForPage(targetPage)
                    let wordToSelect = targetPageWords.last
                    writeLog("📄 Found \(targetPageWords.count) words on page \(targetPage)")

                    currentPage = targetPage
                    writeLog("⬅️  Previous page: \(currentPage)")

                    // Set selection immediately after page loads
                    if let word = wordToSelect {
                        selectedWord = word
                        writeLog("🔘 Selected last aya marker on page: \(word.surah):\(word.ayah):\(word.position)")
                    } else {
                        writeLog("⚠️ No words found to select on page \(targetPage)")
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
            guard let wordData = getOrCreateWordData(
                surah: wordId.surah,
                ayah: wordId.ayah,
                position: wordId.position
            ) else {
                continue
            }

            // Record interaction (review) for this word
            let interaction = WordInteraction(wordData: wordData)
            if wordData.interactions == nil {
                wordData.interactions = []
            }
            wordData.interactions?.append(interaction)
            modelContext.insert(interaction)

            reviewedCount += 1
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

    func previousPage() {
        if currentPage > 1 {
            if shouldShowTwoPages {
                // In 2-page mode, skip by 2 pages (always land on odd page)
                currentPage = max(1, currentPage - 2)
            } else {
                currentPage -= 1
            }

            writeLog("⬅️  Previous page: \(currentPage)")
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
        return getOrCreateWordData(surah: surah, ayah: ayah, position: position)
    }

    // Helper function to get or create WordData
    private func getOrCreateWordData(surah: Int, ayah: Int, position: Int) -> WordData? {
        // Try to fetch existing WordData
        let descriptor = FetchDescriptor<WordData>(
            predicate: #Predicate<WordData> { wordData in
                wordData.surahNumber == surah &&
                wordData.ayahNumber == ayah &&
                wordData.wordPosition == position
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        } else {
            // Create new WordData
            let newWordData = WordData(
                surahNumber: surah,
                ayahNumber: ayah,
                wordPosition: position
            )
            modelContext.insert(newWordData)
            try? modelContext.save()
            return newWordData
        }
    }

    // Synchronous wrapper for calculateMinimumPageWidth using already-loaded data
    func calculateMinimumPageWidth(for pageNumber: Int) -> CGFloat {
        // Use already-loaded lineWords data if available
        let pageWords: [Int: [QuranWord]]
        if pageNumber == currentPage {
            pageWords = lineWords
        } else if pageNumber == currentPage + 1 {
            // Check if we have data for the next page (don't check shouldShowTwoPages - that would create circular dependency)
            pageWords = lineWordsLeft
        } else {
            // Data not loaded yet, return a default width
            return 800.0
        }

        return calculateMinimumPageWidthSync(for: pageNumber, pageWords: pageWords)
    }

    // Async version that fetches data from database
    func calculateMinimumPageWidthAsync(for pageNumber: Int) async -> CGFloat {
        let pageWords = await MushafCache.shared.getPageWords(pageNumber)
        return calculateMinimumPageWidthSync(for: pageNumber, pageWords: pageWords)
    }

    // Shared logic for calculating page width
    private func calculateMinimumPageWidthSync(for pageNumber: Int, pageWords: [Int: [QuranWord]]) -> CGFloat {

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
