import SwiftUI
import SwiftData

extension Notification.Name {
    static let previousPage = Notification.Name("previousPage")
    static let nextPage = Notification.Name("nextPage")
}

struct Ayah: Codable {
    let text: String
    let numberInSurah: Int
    let page: Int
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
    @State private var currentPage: Int = 1
    @Binding var isTextHidden: Bool

    var currentPageAyahs: [Ayah] {
        surah?.ayahs.filter { $0.page == currentPage } ?? []
    }

    var totalPages: Int {
        guard let surah = surah else { return 0 }
        return Set(surah.ayahs.map { $0.page }).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Page header
            HStack {
                Button(action: previousPage) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPage <= 1)

                Spacer()

                if let surah = surah {
                    Text("\(surah.englishName) - Page \(currentPage)")
                        .font(.headline)
                }

                Spacer()

                Button(action: nextPage) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage >= (surah?.ayahs.last?.page ?? 1))
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Page content
            ScrollView {
                VStack(alignment: .trailing, spacing: 20) {
                    ForEach(currentPageAyahs, id: \.numberInSurah) { ayah in
                        if let surah = surah {
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
                    }

                    if currentPageAyahs.isEmpty && surah != nil {
                        Text("No verses on this page")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadJSON()
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
            // Set current page to first page of loaded surah
            currentPage = surah?.ayahs.first?.page ?? 1
        } catch {
            print("Error loading JSON: \(error)")
        }
    }

    func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
        }
    }

    func nextPage() {
        if let maxPage = surah?.ayahs.last?.page, currentPage < maxPage {
            currentPage += 1
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

        // Only affect words on current page
        for ayah in currentPageAyahs {
            let words = ayah.text.split(separator: " ")
            for (index, _) in words.enumerated() {
                let wordData = getOrCreateWordData(surah: surah.number, ayah: ayah.numberInSurah, position: index + 1)
                wordData.isHidden = hidden
            }
        }

        try? modelContext.save()
    }
}
