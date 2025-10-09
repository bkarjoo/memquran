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
    @State private var surah: SurahData?

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 20) {
                if let surah = surah {
                    Text(surah.englishName)
                        .font(.title)
                        .padding()

                    ForEach(surah.ayahs, id: \.numberInSurah) { ayah in
                        HStack(alignment: .top) {
                            Button(action: {
                                toggleBookmark(surah: surah.number, ayah: ayah.numberInSurah)
                            }) {
                                Image(systemName: isBookmarked(surah: surah.number, ayah: ayah.numberInSurah) ? "bookmark.fill" : "bookmark")
                            }

                            Text("\(ayah.numberInSurah)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(ayah.text)
                                .font(.system(size: 24))
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
}
