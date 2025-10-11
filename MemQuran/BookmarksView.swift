import SwiftUI
import SwiftData

struct BookmarksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WordBookmark.createdAt, order: .reverse) private var allBookmarks: [WordBookmark]

    let onBookmarkSelected: (WordIdentifier) -> Void

    @State private var selectedCategory: BookmarkCategory?

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
                        }) {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                Text("All (\(allBookmarks.count))")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == nil ? Color.accentColor : Color.gray.opacity(0.2))
                            .foregroundColor(selectedCategory == nil ? .white : .primary)
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)

                        ForEach(BookmarkCategory.allCases, id: \.self) { category in
                            let count = allBookmarks.filter { $0.categoryEnum == category }.count
                            if count > 0 {
                                Button(action: {
                                    selectedCategory = category
                                }) {
                                    HStack {
                                        Image(systemName: category.icon)
                                        Text("\(category.rawValue) (\(count))")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? categoryColor(category) : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                Divider()

                // Bookmarks list
                if filteredBookmarks.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No bookmarks yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Right-click any word to add a bookmark")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
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
