import SwiftUI
import SwiftData

@main
struct MemQuranApp: App {
    @State private var isTextHidden = false

    var body: some Scene {
        WindowGroup {
            ContentView(isTextHidden: $isTextHidden)
        }
        .modelContainer(for: [
            WordData.self,
            WordNote.self,
            WordLink.self,
            WordMistake.self,
            WordInteraction.self,
            Bookmark.self
        ])
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button(isTextHidden ? "Show Text" : "Hide Text") {
                    isTextHidden.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}
