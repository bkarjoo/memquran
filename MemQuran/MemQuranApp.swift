import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@main
struct MemQuranApp: App {
    @AppStorage("isTextHidden") private var isTextHidden = false
    @AppStorage("currentPage") private var currentPage: Int = 2

    init() {
        print("🎬 STARTING APP INITIALIZATION")
        registerCustomFonts()
        print("✅ App initialization complete - page fonts will load on first view appear")
    }

    func registerCustomFonts() {
        // Only register base fonts needed for UI
        // Page-specific fonts (p1.ttf - p604.ttf) are loaded on-demand by FontLoader
        let fontNames = ["Kitab-Regular.ttf", "UthmanTN.ttf", "ScheherazadeNew.ttf", "me_quran_volt_newmet.ttf", "surah-name-v4.ttf", "QCF_SurahHeader_COLOR-Regular.ttf", "surah-name-v2.ttf"]

        #if os(macOS)
        let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("memquran_debug.log")
        #else
        let logFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("memquran_debug.log")
        #endif

        print("🎬 STARTING FONT REGISTRATION - LAZY LOADING ENABLED")
        writeToLog("🎬 STARTING FONT REGISTRATION - LAZY LOADING ENABLED", to: logFile)

        for fontName in fontNames {
            guard let fontURL = Bundle.main.url(forResource: fontName.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf") else {
                writeToLog("❌ Could not find font: \(fontName)", to: logFile)
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
                writeToLog("✅ Registered font: \(fontName) with PostScript name: \(psName)", to: logFile)
            }
        }

        print("📦 Base font registration complete (\(fontNames.count) fonts). Page fonts will load on-demand.")
        writeToLog("📦 Base font registration complete (\(fontNames.count) fonts). Page fonts will load on-demand.", to: logFile)
        print("✨✨✨ LAZY FONT LOADING IS NOW ACTIVE ✨✨✨")
        writeToLog("✨✨✨ LAZY FONT LOADING IS NOW ACTIVE ✨✨✨", to: logFile)
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
            ContentView(isTextHidden: $isTextHidden)
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
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
                .keyboardShortcut(.upArrow, modifiers: [])

                Button("Next Verse") {
                    NotificationCenter.default.post(name: .nextVerse, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: [])

                Divider()

                Button("Mark Mistake") {
                    NotificationCenter.default.post(name: .markMistake, object: nil)
                }
                .keyboardShortcut("x", modifiers: [])
            }
        }
        #endif
    }
}
