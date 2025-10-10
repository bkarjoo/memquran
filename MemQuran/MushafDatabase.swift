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
