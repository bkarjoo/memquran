import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Lazy font loading service for page-specific Quran fonts
/// Loads fonts on-demand instead of all 604 fonts at startup
class FontLoader {
    static let shared = FontLoader()

    private var loadedFonts: Set<Int> = []
    private let queue = DispatchQueue(label: "com.memquran.fontloader", attributes: .concurrent)
    private let logFile: URL

    private init() {
        #if os(macOS)
        logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("memquran_debug.log")
        #else
        logFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("memquran_debug.log")
        #endif
    }

    /// Ensures the font for a specific page is loaded
    /// Thread-safe and idempotent - safe to call multiple times
    func ensureFontLoaded(forPage page: Int) {
        // Check if already loaded (read lock)
        var alreadyLoaded = false
        queue.sync {
            alreadyLoaded = loadedFonts.contains(page)
        }

        guard !alreadyLoaded else { return }

        // Load the font
        let fontName = "p\(page).ttf"

        guard let fontURL = Bundle.main.url(forResource: "p\(page)", withExtension: "ttf") else {
            // Font file not found - skip silently (QPC fonts may not all exist)
            return
        }

        guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider) else {
            writeToLog("❌ Could not load font data from: \(fontName)")
            return
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            // Check if error is "already registered" - this is fine
            if let error = error?.takeRetainedValue() {
                let errorDescription = String(describing: error)
                if !errorDescription.contains("already registered") {
                    writeToLog("❌ Error registering font \(fontName): \(errorDescription)")
                }
            }
        } else {
            let psName = font.postScriptName as String? ?? "unknown"
            writeToLog("✅ Registered page font: \(fontName) (PS: \(psName))")
        }

        // Mark as loaded (write lock)
        queue.async(flags: .barrier) { [weak self] in
            self?.loadedFonts.insert(page)
        }
    }

    /// Preload fonts for surrounding pages in the background
    /// Call this after loading the current page to prepare for navigation
    func preloadSurroundingPages(around currentPage: Int, range: Int = 2) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let startPage = max(1, currentPage - range)
            let endPage = min(604, currentPage + range)

            for page in startPage...endPage {
                self?.ensureFontLoaded(forPage: page)
            }
        }
    }

    private func writeToLog(_ message: String) {
        let timestamp = Date()
        let logMessage = "[\(timestamp)] [FontLoader] \(message)\n"
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
}
