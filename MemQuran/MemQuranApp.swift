import SwiftUI
import SwiftData

@main
struct MemQuranApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Bookmark.self)
    }
}
