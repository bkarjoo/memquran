import SwiftUI

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
}
