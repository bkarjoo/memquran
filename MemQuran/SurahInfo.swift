import Foundation
import SQLite3

struct SurahInfo {
    let id: Int
    let verseCount: Int

    private static var db: OpaquePointer?

    static func openDatabase() {
        guard db == nil else { return }

        if let dbPath = Bundle.main.path(forResource: "surah-names", ofType: "db") {
            if sqlite3_open(dbPath, &db) == SQLITE_OK {
                print("✅ Surah names database opened successfully")
            } else {
                print("❌ Error opening surah names database")
            }
        } else {
            print("❌ Surah names database not found in bundle")
        }
    }

    static func getVerseCount(for surahNumber: Int) -> Int {
        openDatabase()

        guard let database = db else {
            print("❌ Database not available")
            return 0
        }

        let query = "SELECT verses_count FROM chapters WHERE id = ?;"
        var statement: OpaquePointer?
        var verseCount = 0

        if sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(surahNumber))

            if sqlite3_step(statement) == SQLITE_ROW {
                verseCount = Int(sqlite3_column_int(statement, 0))
            }
        } else {
            print("❌ Error preparing query for surah \(surahNumber)")
        }

        sqlite3_finalize(statement)
        return verseCount
    }
}
