import SwiftUI
import SwiftData

struct Ayah: Codable {
    let text: String
    let numberInSurah: Int
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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @Query private var wordDataRecords: [WordData]
    @State private var surah: SurahData?
    @Binding var isTextHidden: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 20) {
                if let surah = surah {
                    Text(surah.englishName)
                        .font(.title)
                        .padding()

                    ForEach(surah.ayahs, id: \.numberInSurah) { ayah in
                        HStack(alignment: .top, spacing: 8) {
                            Button(action: {
                                toggleBookmark(surah: surah.number, ayah: ayah.numberInSurah)
                            }) {
                                Image(systemName: isBookmarked(surah: surah.number, ayah: ayah.numberInSurah) ? "bookmark.fill" : "bookmark")
                            }

                            Text("\(ayah.numberInSurah)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                let words = ayah.text.split(separator: " ")
                                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                                    let wordData = getWordData(surah: surah.number, ayah: ayah.numberInSurah, position: index + 1)
                                    Text(String(word))
                                        .font(.system(size: 24))
                                        .opacity(wordData?.isHidden ?? false ? 0 : 1)
                                }
                            }
                            .multilineTextAlignment(.trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("Loading...")
                }
            }
            .padding()
        }
        .onAppear {
            loadJSON()
        }
        .onChange(of: isTextHidden) { oldValue, newValue in
            toggleAllWordsHidden(hidden: newValue)
        }
    }

    func loadJSON() {
        guard let url = Bundle.main.url(forResource: "surah_1_al-fatiha", withExtension: "json") else {
            print("JSON file not found")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let response = try JSONDecoder().decode(Response.self, from: data)
            surah = response.data
        } catch {
            print("Error loading JSON: \(error)")
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

    func getOrCreateWordData(surah: Int, ayah: Int, position: Int) -> WordData {
        if let existing = getWordData(surah: surah, ayah: ayah, position: position) {
            return existing
        }
        let newWordData = WordData(surahNumber: surah, ayahNumber: ayah, wordPosition: position)
        modelContext.insert(newWordData)
        return newWordData
    }

    func toggleAllWordsHidden(hidden: Bool) {
        guard let surah = surah else { return }

        for ayah in surah.ayahs {
            let words = ayah.text.split(separator: " ")
            for (index, _) in words.enumerated() {
                let wordData = getOrCreateWordData(surah: surah.number, ayah: ayah.numberInSurah, position: index + 1)
                wordData.isHidden = hidden
            }
        }

        try? modelContext.save()
    }
}
