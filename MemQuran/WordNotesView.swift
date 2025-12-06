import SwiftUI
import SwiftData

/// A floating view for managing unlimited notes on a specific word.
/// Notes are loaded on-demand (not cached) and fetched directly from SwiftData when the view appears.
struct WordNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let wordId: WordIdentifier

    // Notes are fetched on-demand, not from cache
    @State private var notes: [WordNote] = []
    @State private var isLoading = true
    @State private var newNoteContent: String = ""
    @State private var editingNote: WordNote? = nil
    @State private var editingContent: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            if isLoading {
                loadingView
            } else {
                // Notes list and editor
                ScrollView {
                    VStack(spacing: 12) {
                        // Existing notes
                        ForEach(notes.sorted { $0.createdAt > $1.createdAt }) { note in
                            noteCard(for: note)
                        }

                        if notes.isEmpty {
                            emptyStateView
                        }
                    }
                    .padding()
                }

                Divider()

                // New note input
                newNoteInput
            }
        }
        .frame(width: 420, height: 520)
        .onAppear {
            loadNotes()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Word Notes")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Surah \(wordId.surah), Ayah \(wordId.ayah), Word \(wordId.position)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading notes...")
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No notes yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add your first note below")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 40)
    }

    // MARK: - Note Card

    private func noteCard(for note: WordNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if editingNote?.id == note.id {
                // Edit mode
                TextEditor(text: $editingContent)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                HStack {
                    Button("Cancel") {
                        editingNote = nil
                        editingContent = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    Spacer()

                    Button("Save") {
                        saveEditedNote(note)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editingContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                // View mode
                Text(note.content)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        editingNote = note
                        editingContent = note.content
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)

                    Button(action: {
                        deleteNote(note)
                    }) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - New Note Input

    private var newNoteInput: some View {
        VStack(spacing: 12) {
            TextEditor(text: $newNoteContent)
                .frame(height: 80)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    Group {
                        if newNoteContent.isEmpty {
                            Text("Write a new note...")
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.leading, 12)
                                .padding(.top, 16)
                        }
                    },
                    alignment: .topLeading
                )

            HStack {
                Text("\(notes.count) note\(notes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Add Note") {
                    addNewNote()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
    }

    // MARK: - Data Operations (On-Demand, Not Cached)

    /// Load notes directly from SwiftData - not from any cache
    private func loadNotes() {
        isLoading = true

        // Extract values for #Predicate macro (it requires primitive values, not struct property access)
        let surah = wordId.surah
        let ayah = wordId.ayah
        let position = wordId.position

        // First, find the WordData for this word
        let descriptor = FetchDescriptor<WordData>(
            predicate: #Predicate<WordData> { wordData in
                wordData.surahNumber == surah &&
                wordData.ayahNumber == ayah &&
                wordData.wordPosition == position
            }
        )

        if let wordData = try? modelContext.fetch(descriptor).first {
            // Fetch notes directly - SwiftData loads them on-demand
            notes = wordData.notes ?? []
        } else {
            notes = []
        }

        isLoading = false
    }

    /// Add a new note to this word
    private func addNewNote() {
        let trimmedContent = newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        // Get or create WordData
        guard let wordData = getOrCreateWordData() else {
            print("❌ Could not find or create word data for note")
            return
        }

        // Create the new note
        let newNote = WordNote(content: trimmedContent, wordData: wordData)

        // Add to relationships
        if wordData.notes == nil {
            wordData.notes = []
        }
        wordData.notes?.append(newNote)
        modelContext.insert(newNote)

        do {
            try modelContext.save()
            print("📝 Note saved for \(wordId.surah):\(wordId.ayah):\(wordId.position)")

            // Refresh the local list
            notes.append(newNote)
            newNoteContent = ""
        } catch {
            print("❌ Error saving note: \(error)")
        }
    }

    /// Save edits to an existing note
    private func saveEditedNote(_ note: WordNote) {
        let trimmedContent = editingContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        note.content = trimmedContent

        do {
            try modelContext.save()
            print("📝 Note updated")

            // Update local list
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = note
            }

            editingNote = nil
            editingContent = ""
        } catch {
            print("❌ Error updating note: \(error)")
        }
    }

    /// Delete a note
    private func deleteNote(_ note: WordNote) {
        modelContext.delete(note)

        do {
            try modelContext.save()
            print("🗑️ Note deleted")

            // Remove from local list
            notes.removeAll { $0.id == note.id }
        } catch {
            print("❌ Error deleting note: \(error)")
        }
    }

    /// Get or create WordData for this word identifier
    private func getOrCreateWordData() -> WordData? {
        // Extract values for #Predicate macro (it requires primitive values, not struct property access)
        let surah = wordId.surah
        let ayah = wordId.ayah
        let position = wordId.position

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
                surahNumber: wordId.surah,
                ayahNumber: wordId.ayah,
                wordPosition: wordId.position
            )
            modelContext.insert(newWordData)
            try? modelContext.save()
            return newWordData
        }
    }
}
