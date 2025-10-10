import SwiftUI
import SwiftData

// Mushaf data models
public struct MushafLine {
    let pageNumber: Int
    let lineNumber: Int
    let lineType: String
    let isCentered: Bool
    let firstWordId: Int?
    let lastWordId: Int?
    let surahNumber: Int?
}

public struct QuranWord {
    let id: Int
    let location: String
    let surah: Int
    let ayah: Int
    let word: Int
    let text: String
}

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

struct PageContentView: View {
    let lines: [MushafLine]
    let lineWords: [Int: [QuranWord]]  // lineNumber -> words
    let fontFamily: String
    let baseFontSize: CGFloat
    let lineHeight: CGFloat
    let lineSpacing: CGFloat
    let wordSpacing: CGFloat
    let getWordData: (Int, Int, Int) -> WordData?

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
                                getWordData: getWordData
                            )
                        }
                    }
                    //                     .padding(.horizontal)
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

                        Text(quranWord.text)
                            .font(.custom(fontFamily, size: baseFontSize))
                            .opacity(wordData?.isHidden == true ? 0 : 1)
                            .position(x: positions[index] ?? 0, y: lineHeight / 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: lineInfo?.isCentered == true ? .center : .trailing)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .frame(height: lineHeight)
    }

    private func calculateWordPositions(containerWidth: CGFloat) -> [Int: CGFloat] {
        guard words.count > 0, containerWidth > 0 else {
            return [:]
        }

        // Calculate text widths using NSAttributedString
        let font = NSFont(name: fontFamily, size: baseFontSize) ?? NSFont.systemFont(ofSize: baseFontSize)
        var wordWidths: [CGFloat] = []
        var totalTextWidth: CGFloat = 0

        for word in words {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = (word.text as NSString).size(withAttributes: attributes)
            wordWidths.append(size.width)
            totalTextWidth += size.width
        }

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
    @Query private var wordDataRecords: [WordData]
    @State private var currentPage: Int = 2  // Start at page 2 (Al-Baqarah)
    @State private var lines: [MushafLine] = []
    @State private var lineWords: [Int: [QuranWord]] = [:]
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
                .disabled(currentPage >= 604)

                Spacer()

                Text("Page \(currentPage) of 604")
                    .font(.headline)

                Spacer()

                Button(action: previousPage) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage <= 1)

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
                getWordData: getWordData
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
        // Get lines for this page from layout database
        lines = MushafDatabase.shared.getLinesForPage(pageNumber)

        // For each ayah line, get the words
        var wordsDict: [Int: [QuranWord]] = [:]
        for line in lines {
            if line.lineType == "ayah",
               let firstId = line.firstWordId,
               let lastId = line.lastWordId {
                let words = MushafDatabase.shared.getWords(from: firstId, to: lastId)
                wordsDict[line.lineNumber] = words

                // Create WordData entries for persistence
                for word in words {
                    let wordData = getOrCreateWordData(
                        surah: word.surah,
                        ayah: word.ayah,
                        position: word.word,
                        lineNumber: line.lineNumber,
                        positionInLine: 0  // TODO: Calculate position in line
                    )
                    wordData.lineNumber = line.lineNumber
                }
            }
        }
        lineWords = wordsDict

        writeLog("📄 Loaded page \(pageNumber) with \(lines.count) lines")
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

    func toggleAllWordsHidden(hidden: Bool) {
        // Toggle all words on current page
        for (_, words) in lineWords {
            for word in words {
                let wordData = getOrCreateWordData(surah: word.surah, ayah: word.ayah, position: word.word)
                wordData.isHidden = hidden
            }
        }
        try? modelContext.save()
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
import Foundation
import SQLite3

public class MushafDatabase {
    private var layoutDB: OpaquePointer?
    private var wordsDB: OpaquePointer?

    public static let shared = MushafDatabase()

    private init() {
        openDatabases()
    }

    deinit {
        closeDatabases()
    }

    private func openDatabases() {
        // Open layout database
        if let layoutPath = Bundle.main.path(forResource: "uthmani-15-lines", ofType: "db") {
            if sqlite3_open(layoutPath, &layoutDB) != SQLITE_OK {
                print("❌ Error opening layout database")
            } else {
                print("✅ Layout database opened successfully")
            }
        } else {
            print("❌ Layout database not found in bundle")
        }

        // Open words database
        if let wordsPath = Bundle.main.path(forResource: "uthmani", ofType: "db") {
            if sqlite3_open(wordsPath, &wordsDB) != SQLITE_OK {
                print("❌ Error opening words database")
            } else {
                print("✅ Words database opened successfully")
            }
        } else {
            print("❌ Words database not found in bundle")
        }
    }

    private func closeDatabases() {
        if layoutDB != nil {
            sqlite3_close(layoutDB)
            layoutDB = nil
        }
        if wordsDB != nil {
            sqlite3_close(wordsDB)
            wordsDB = nil
        }
    }

    // MARK: - Query Layout

    public func getLinesForPage(_ pageNumber: Int) -> [MushafLine] {
        guard let db = layoutDB else {
            print("❌ Layout database not available")
            return []
        }

        let query = """
        SELECT page_number, line_number, line_type, is_centered, first_word_id, last_word_id, surah_number
        FROM pages
        WHERE page_number = ?
        ORDER BY line_number;
        """

        var statement: OpaquePointer?
        var lines: [MushafLine] = []

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(pageNumber))

            while sqlite3_step(statement) == SQLITE_ROW {
                let pageNum = Int(sqlite3_column_int(statement, 0))
                let lineNum = Int(sqlite3_column_int(statement, 1))
                let lineType = String(cString: sqlite3_column_text(statement, 2))
                let isCentered = sqlite3_column_int(statement, 3) == 1

                // Handle nullable integers
                let firstWordId = sqlite3_column_type(statement, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 4))
                let lastWordId = sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 5))
                let surahNum = sqlite3_column_type(statement, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 6))

                let line = MushafLine(
                    pageNumber: pageNum,
                    lineNumber: lineNum,
                    lineType: lineType,
                    isCentered: isCentered,
                    firstWordId: firstWordId,
                    lastWordId: lastWordId,
                    surahNumber: surahNum
                )
                lines.append(line)
            }
        } else {
            print("❌ Error preparing layout query")
        }

        sqlite3_finalize(statement)
        return lines
    }

    // MARK: - Query Words

    public func getWords(from firstId: Int, to lastId: Int) -> [QuranWord] {
        guard let db = wordsDB else {
            print("❌ Words database not available")
            return []
        }

        let query = """
        SELECT id, location, surah, ayah, word, text
        FROM words
        WHERE id BETWEEN ? AND ?
        ORDER BY id;
        """

        var statement: OpaquePointer?
        var words: [QuranWord] = []

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(firstId))
            sqlite3_bind_int(statement, 2, Int32(lastId))

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let location = String(cString: sqlite3_column_text(statement, 1))
                let surah = Int(sqlite3_column_int(statement, 2))
                let ayah = Int(sqlite3_column_int(statement, 3))
                let word = Int(sqlite3_column_int(statement, 4))
                let text = String(cString: sqlite3_column_text(statement, 5))

                let quranWord = QuranWord(
                    id: id,
                    location: location,
                    surah: surah,
                    ayah: ayah,
                    word: word,
                    text: text
                )
                words.append(quranWord)
            }
        } else {
            print("❌ Error preparing words query")
        }

        sqlite3_finalize(statement)
        return words
    }

    // MARK: - Helper: Get All Words for Page

    func getPageWords(_ pageNumber: Int) -> [(line: Int, words: [QuranWord])] {
        let lines = getLinesForPage(pageNumber)
        var result: [(line: Int, words: [QuranWord])] = []

        for line in lines {
            if line.lineType == "ayah",
               let firstId = line.firstWordId,
               let lastId = line.lastWordId {
                let words = getWords(from: firstId, to: lastId)
                result.append((line: line.lineNumber, words: words))
            }
        }

        return result
    }
}
