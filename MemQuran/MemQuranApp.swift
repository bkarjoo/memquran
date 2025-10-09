import SwiftUI
import SwiftData

@main
struct MemQuranApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            WordProgress.self,
            WordNote.self,
            WordLink.self,
            WordMistake.self,
            WordInteraction.self,
            Bookmark.self
        ])
    }
}
