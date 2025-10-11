import SwiftUI
import SwiftData
import AppKit

@main
struct MemQuranApp: App {
    @State private var isTextHidden = false

    init() {
        registerCustomFonts()
    }

    func registerCustomFonts() {
        var fontNames = ["Kitab-Regular.ttf", "UthmanTN.ttf", "ScheherazadeNew.ttf", "me_quran_volt_newmet.ttf"]

        // Add all 604 QPC V1 page-specific fonts
        for i in 1...604 {
            fontNames.append("p\(i).ttf")
        }

        let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("memquran_debug.log")

        for fontName in fontNames {
            guard let fontURL = Bundle.main.url(forResource: fontName.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf") else {
                // Don't log missing QPC fonts to avoid spam
                if !fontName.hasPrefix("p") {
                    writeToLog("❌ Could not find font: \(fontName)", to: logFile)
                }
                continue
            }

            guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
                  let font = CGFont(fontDataProvider) else {
                writeToLog("❌ Could not load font from: \(fontName)", to: logFile)
                continue
            }

            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(font, &error) {
                writeToLog("❌ Error registering font \(fontName)", to: logFile)
            } else {
                let psName = font.postScriptName as String? ?? "unknown"
                // Only log base fonts (not QPC fonts to reduce log spam)
                if !fontName.hasPrefix("p") {
                    writeToLog("✅ Registered font: \(fontName) with PostScript name: \(psName)", to: logFile)
                }
            }
        }

        writeToLog("📦 Font registration complete (608 fonts). Ready to use QPC V1 layout.", to: logFile)
    }

    func writeToLog(_ message: String, to logFile: URL) {
        let timestamp = Date()
        let logMessage = "[\(timestamp)] \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WordData.self,
            WordNote.self,
            WordLink.self,
            WordMistake.self,
            WordInteraction.self,
            WordBookmark.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(isTextHidden: $isTextHidden, modelContext: sharedModelContainer.mainContext)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button(isTextHidden ? "Show Text" : "Hide Text") {
                    isTextHidden.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }

            CommandMenu("Navigate") {
                Button("Previous Page") {
                    NotificationCenter.default.post(name: .previousPage, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])

                Button("Next Page") {
                    NotificationCenter.default.post(name: .nextPage, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])

                Divider()

                Button("Previous Word") {
                    NotificationCenter.default.post(name: .previousWord, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button("Next Word") {
                    NotificationCenter.default.post(name: .nextWord, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Divider()

                Button("Previous Verse") {
                    NotificationCenter.default.post(name: .previousVerse, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button("Next Verse") {
                    NotificationCenter.default.post(name: .nextVerse, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button("Mark Mistake") {
                    NotificationCenter.default.post(name: .markMistake, object: nil)
                }
                .keyboardShortcut("x", modifiers: [])
            }
        }
    }
}
