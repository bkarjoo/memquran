import SwiftUI
import SwiftData

struct BookmarksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WordBookmark.createdAt, order: .reverse) private var allBookmarks: [WordBookmark]
    @Query(sort: \WordMistake.timestamp, order: .reverse) private var allMistakes: [WordMistake]

    let onBookmarkSelected: (WordIdentifier) -> Void
    let onErrorSelected: ((WordIdentifier) -> Void)?

    @State private var selectedCategory: BookmarkCategory?
    @State private var showingErrors: Bool = false

    var filteredBookmarks: [WordBookmark] {
        if let category = selectedCategory {
            return allBookmarks.filter { $0.categoryEnum == category }
        }
        return allBookmarks
    }

    var bookmarksByCategory: [BookmarkCategory: [WordBookmark]] {
        Dictionary(grouping: filteredBookmarks) { $0.categoryEnum }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All bookmarks button
                        Button(action: {
                            selectedCategory = nil
                            showingErrors = false
                        }) {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                Text("All (\(allBookmarks.count))")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(!showingErrors && selectedCategory == nil ? Color.accentColor : Color.gray.opacity(0.2))
                            .foregroundColor(!showingErrors && selectedCategory == nil ? .white : .primary)
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)

                        ForEach(BookmarkCategory.allCases, id: \.self) { category in
                            let count = allBookmarks.filter { $0.categoryEnum == category }.count
                            if count > 0 {
                                Button(action: {
                                    selectedCategory = category
                                    showingErrors = false
                                }) {
                                    HStack {
                                        Image(systemName: category.icon)
                                        Text("\(category.rawValue) (\(count))")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(!showingErrors && selectedCategory == category ? categoryColor(category) : Color.gray.opacity(0.2))
                                    .foregroundColor(!showingErrors && selectedCategory == category ? .white : .primary)
                                    .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Errors button (from mistakes)
                        if !allMistakes.isEmpty {
                            let uniqueErrorWords = Set(allMistakes.compactMap { mistake -> String? in
                                guard let wordData = mistake.wordData else { return nil }
                                return "\(wordData.surahNumber):\(wordData.ayahNumber):\(wordData.wordPosition)"
                            })

                            Button(action: {
                                showingErrors = true
                                selectedCategory = nil
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text("Errors (\(uniqueErrorWords.count))")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(showingErrors ? Color.red : Color.gray.opacity(0.2))
                                .foregroundColor(showingErrors ? .white : .primary)
                                .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                Divider()

                // Bookmarks/Errors list
                if showingErrors {
                    // Show errors from mistakes
                    if allMistakes.isEmpty {
                        emptyStateView(icon: "xmark.circle", title: "No errors yet", subtitle: "Mistakes will appear here")
                    } else {
                        errorsList
                    }
                } else {
                    // Show bookmarks
                    if filteredBookmarks.isEmpty {
                        emptyStateView(icon: "bookmark.slash", title: "No bookmarks yet", subtitle: "Right-click any word to add a bookmark")
                    } else {
                        bookmarksList
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
    }

    @ViewBuilder
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var bookmarksList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredBookmarks) { bookmark in
                    BookmarkRow(bookmark: bookmark, onSelect: {
                        let wordId = WordIdentifier(
                            surah: bookmark.surahNumber,
                            ayah: bookmark.ayahNumber,
                            position: bookmark.wordPosition
                        )
                        onBookmarkSelected(wordId)
                        dismiss()
                    }, onDelete: {
                        deleteBookmark(bookmark)
                    })

                    Divider()
                }
            }
        }
    }

    private var errorsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Group mistakes by word to show unique words
                let uniqueMistakes = Dictionary(grouping: allMistakes) { mistake -> String? in
                    guard let wordData = mistake.wordData else { return nil }
                    return "\(wordData.surahNumber):\(wordData.ayahNumber):\(wordData.wordPosition)"
                }
                .compactMap { key, mistakes -> (WordMistake, Int)? in
                    guard let key = key, let first = mistakes.first else { return nil }
                    return (first, mistakes.count)
                }
                .sorted { $0.0.timestamp > $1.0.timestamp }

                ForEach(uniqueMistakes, id: \.0.id) { mistake, count in
                    if let wordData = mistake.wordData {
                        ErrorRow(
                            surahNumber: wordData.surahNumber,
                            ayahNumber: wordData.ayahNumber,
                            wordPosition: wordData.wordPosition,
                            mistakeCount: count,
                            timestamp: mistake.timestamp,
                            onSelect: {
                                let wordId = WordIdentifier(
                                    surah: wordData.surahNumber,
                                    ayah: wordData.ayahNumber,
                                    position: wordData.wordPosition
                                )
                                // Use error-specific callback if provided, otherwise use bookmark callback
                                if let onErrorSelected = onErrorSelected {
                                    onErrorSelected(wordId)
                                } else {
                                    onBookmarkSelected(wordId)
                                }
                                dismiss()
                            }
                        )

                        Divider()
                    }
                }
            }
        }
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

    private func deleteBookmark(_ bookmark: WordBookmark) {
        modelContext.delete(bookmark)

        do {
            try modelContext.save()
            print("🗑️ Bookmark deleted: \(bookmark.surahNumber):\(bookmark.ayahNumber):\(bookmark.wordPosition)")
        } catch {
            print("❌ Error deleting bookmark: \(error)")
        }
    }
}

struct BookmarkRow: View {
    let bookmark: WordBookmark
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Main bookmark content (clickable)
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    // Category icon
                    Image(systemName: bookmark.categoryEnum.icon)
                        .font(.title2)
                        .foregroundColor(categoryColor(bookmark.categoryEnum))
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        // Location
                        Text("Surah \(bookmark.surahNumber), Ayah \(bookmark.ayahNumber), Word \(bookmark.wordPosition)")
                            .font(.headline)
                            .foregroundColor(.primary)

                        // Category
                        Text(bookmark.categoryEnum.rawValue)
                            .font(.subheadline)
                            .foregroundColor(categoryColor(bookmark.categoryEnum))

                        // Description (if exists)
                        if !bookmark.bookmarkDescription.isEmpty {
                            Text(bookmark.bookmarkDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        // Timestamp
                        Text(bookmark.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .help("Delete Bookmark")
            .padding(.trailing, 8)
        }
        .background(Color.clear)
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
}

struct ErrorRow: View {
    let surahNumber: Int
    let ayahNumber: Int
    let wordPosition: Int
    let mistakeCount: Int
    let timestamp: Date
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Error icon
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    // Location
                    Text("Surah \(surahNumber), Ayah \(ayahNumber), Word \(wordPosition)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Mistake count
                    Text("\(mistakeCount) mistake\(mistakeCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.red)

                    // Timestamp
                    Text(timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
