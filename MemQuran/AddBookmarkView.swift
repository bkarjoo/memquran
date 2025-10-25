import SwiftUI
import SwiftData

struct AddBookmarkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let wordId: WordIdentifier

    @State private var selectedCategory: BookmarkCategory = .memorization
    @State private var bookmarkDescription: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Bookmark")
                .font(.title2)
                .fontWeight(.bold)

            Text("Surah \(wordId.surah), Ayah \(wordId.ayah), Word \(wordId.position)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // Category selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.headline)

                ForEach(BookmarkCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(selectedCategory == category ? .white : categoryColor(category))
                                .frame(width: 20)

                            Text(category.rawValue)
                                .foregroundColor(selectedCategory == category ? .white : .primary)

                            Spacer()

                            if selectedCategory == category {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedCategory == category ? categoryColor(category) : Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Description field
            VStack(alignment: .leading, spacing: 6) {
                Text("Description (Optional)")
                    .font(.headline)

                TextEditor(text: $bookmarkDescription)
                    .frame(height: 60)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save Bookmark") {
                    saveBookmark()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 380, height: 480)
    }

    private func categoryColor(_ category: BookmarkCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        default: return .blue
        }
    }

    private func saveBookmark() {
        guard let wordData = getOrCreateWordData(
            surah: wordId.surah,
            ayah: wordId.ayah,
            position: wordId.position
        ) else {
            print("❌ Could not find word data for bookmark")
            dismiss()
            return
        }

        let bookmark = WordBookmark(
            surahNumber: wordId.surah,
            ayahNumber: wordId.ayah,
            wordPosition: wordId.position,
            category: selectedCategory,
            description: bookmarkDescription,
            wordData: wordData
        )

        if wordData.bookmarks == nil {
            wordData.bookmarks = []
        }
        wordData.bookmarks?.append(bookmark)
        modelContext.insert(bookmark)

        do {
            try modelContext.save()
            print("📑 Bookmark saved: \(wordId.surah):\(wordId.ayah):\(wordId.position) - \(selectedCategory.rawValue)")
        } catch {
            print("❌ Error saving bookmark: \(error)")
        }

        dismiss()
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
}
