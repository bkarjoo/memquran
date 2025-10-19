import SwiftUI
import AVFoundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// FlowLayout for wrapping words - RTL layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = maxWidth  // Start from the right for RTL
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                // Check if word fits on current line (RTL: check if x - size.width < 0)
                if x - size.width < 0 && x < maxWidth {
                    x = maxWidth  // Reset to right edge
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                // Position word from right to left
                x -= size.width
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x -= spacing  // Add spacing before next word
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#if os(macOS)
/// AppKit-backed text view for reliable Arabic text rendering on macOS
/// Bypasses SwiftUI's font resolution to use NSFont directly with runtime-registered fonts
struct ArabicTextView: NSViewRepresentable {
    let text: String
    let fontName: String
    let size: CGFloat
    let lineHeightMultiplier: Double

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 0
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        // Try to get the requested font
        var font: NSFont
        if let nsFont = NSFont(name: fontName, size: size) {
            font = nsFont
            print("✅ macOS ArabicTextView font used: \(fontName) @ \(size)")
        } else if let fallback = NSFont(name: "ScheherazadeNew-Regular", size: size) {
            font = fallback
            print("⚠️ macOS ArabicTextView fallback to ScheherazadeNew-Regular @ \(size)")
        } else {
            font = NSFont.systemFont(ofSize: size)
            print("⚠️ macOS ArabicTextView using system font @ \(size)")
        }

        // Create paragraph style for RTL and line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.baseWritingDirection = .rightToLeft
        paragraphStyle.alignment = .right

        // Calculate line height based on multiplier
        let calculatedLineHeight = size * CGFloat(lineHeightMultiplier)
        paragraphStyle.minimumLineHeight = calculatedLineHeight
        paragraphStyle.maximumLineHeight = calculatedLineHeight

        // Create attributed string with all necessary attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .ligature: 1,
            .kern: 0
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        textField.attributedStringValue = attributedString
    }
}
#endif

struct AudioMemorizationView: View {
    // MARK: - Properties

    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var audioService = AudioService.shared
    @State private var currentVerseIndex = 0
    @State private var pageWords: [(line: Int, words: [QuranWord])] = []
    @State private var pageVerses: [(surah: Int, ayah: Int, words: [QuranWord])] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var audioPlaybackDuration: TimeInterval = 0
    @State private var isSessionActive = true
    @Binding var currentPage: Int

    let onPageAdvance: (Int) -> [(line: Int, words: [QuranWord])]

    @Environment(\.dismiss) private var dismiss

    // Settings from AppStorage (matching what Settings uses)
    @AppStorage("fontSize") private var fontSize: Double = 28
    @AppStorage("lineHeightMultiplier") private var lineHeightMultiplier: Double = 2.2
    @AppStorage("fontFamily") private var fontFamily: String = "ScheherazadeNew-Regular"

    // Get the proper font for the current platform
    private func getFont(size: CGFloat) -> Font {
        #if os(iOS)
        // iOS implementation - simpler, just use custom or system
        if UIFont(name: fontFamily, size: 12) != nil {
            return .custom(fontFamily, size: size)
        }
        // Fallback to ScheherazadeNew-Regular if available
        if UIFont(name: "ScheherazadeNew-Regular", size: 12) != nil {
            return .custom("ScheherazadeNew-Regular", size: size)
        }
        // Final fallback to system font
        return .system(size: size)

        #elseif os(macOS)
        // macOS implementation - SwiftUI's .custom() doesn't work with runtime-registered fonts
        // We MUST use Font(nsFont) with the actual NSFont instance
        print("DEBUG: Attempting to use font: '\(fontFamily)' at size \(size)")

        // Try the selected font first - create NSFont with the actual size
        if let nsFont = NSFont(name: fontFamily, size: size) {
            print("DEBUG: Created NSFont '\(fontFamily)' at size \(size), wrapping in Font()")
            return Font(nsFont)
        }

        // Fallback to ScheherazadeNew-Regular if available
        if let nsFont = NSFont(name: "ScheherazadeNew-Regular", size: size) {
            print("DEBUG: Created NSFont 'ScheherazadeNew-Regular' at size \(size), wrapping in Font()")
            return Font(nsFont)
        }

        // Final fallback to system font
        print("DEBUG: No custom fonts found, using system font at size \(size)")
        return .system(size: size)
        #endif
    }

    // Runtime verification helper for debugging
    private func verifyFontOnMacOS() {
        #if os(macOS)
        print("=== macOS Font Verification ===")
        print("Selected from settings: \(fontFamily)")
        print("NSFont resolvable? \(NSFont(name: fontFamily, size: 12) != nil)")
        print("NSFont resolvable for 'ScheherazadeNew-Regular'? \(NSFont(name: "ScheherazadeNew-Regular", size: 12) != nil)")

        // Check available PostScript names
        if let availableNames = CTFontManagerCopyAvailablePostScriptNames() as? [String] {
            let scheherazadeNames = availableNames.filter { $0.contains("Scheherazade") }
            print("PostScript names containing 'Scheherazade': \(scheherazadeNames)")
            print("PostScript names list contains 'ScheherazadeNew-Regular'? \(availableNames.contains("ScheherazadeNew-Regular"))")
        }

        // Check bundle resource
        if let bundleURL = Bundle.main.url(forResource: "ScheherazadeNew", withExtension: "ttf") {
            print("ScheherazadeNew.ttf found in bundle at: \(bundleURL)")
        } else {
            print("WARNING: ScheherazadeNew.ttf NOT found in bundle!")
        }
        print("================================")
        #endif
    }

    // MARK: - Initialization

    init(currentPage: Binding<Int>, pageWords: [(line: Int, words: [QuranWord])], onPageAdvance: @escaping (Int) -> [(line: Int, words: [QuranWord])]) {
        self._currentPage = currentPage
        self._pageWords = State(initialValue: pageWords)
        self.onPageAdvance = onPageAdvance

        // Build initial page verses
        let verses = Self.buildPageVerses(from: pageWords)
        self._pageVerses = State(initialValue: verses)
    }

    // MARK: - Helper Methods

    /// Extract unique verses from page words
    private static func buildPageVerses(from pageWords: [(line: Int, words: [QuranWord])]) -> [(surah: Int, ayah: Int, words: [QuranWord])] {
        var verses: [(surah: Int, ayah: Int, words: [QuranWord])] = []
        var processedVerses = Set<String>()

        for (_, words) in pageWords {
            for word in words {
                let verseKey = "\(word.surah):\(word.ayah)"
                if !processedVerses.contains(verseKey) {
                    processedVerses.insert(verseKey)
                    // Collect all QuranWord objects for this verse
                    let verseWords = pageWords
                        .flatMap { $0.words }
                        .filter { $0.surah == word.surah && $0.ayah == word.ayah }
                        .sorted { $0.word < $1.word }
                    verses.append((surah: word.surah, ayah: word.ayah, words: verseWords))
                }
            }
        }

        // Sort verses by surah and ayah
        verses.sort { ($0.surah, $0.ayah) < ($1.surah, $1.ayah) }
        return verses
    }

    // MARK: - Body

    var body: some View {
        print("🔵 AUDIO VIEW BODY BUILDING - Font: \(fontFamily), Verses count: \(pageVerses.count)")

        #if os(iOS)
        // iOS: Use a fixed layout that ensures controls are always visible
        return VStack(spacing: 0) {
            // Header
            headerView

            if !audioService.isNetworkAvailable() {
                networkWarningView
            }

            // Main Content
            if isLoading {
                Spacer()
                loadingView
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                errorView(error)
                Spacer()
            } else if !pageVerses.isEmpty {
                // Current verse display (scrollable if too long)
                currentVerseView
                    .padding(.top, 20)

                Spacer()
                    .frame(minHeight: 10, maxHeight: 20)

                // Progress indicator (fixed position)
                progressView

                // Controls (fixed position at bottom)
                controlsView
                    .padding(.bottom, 20)
            }
        }
        .padding()
        .navigationBarHidden(true)
        .onAppear {
            print("🟢 AUDIO VIEW ON APPEAR - Starting session")
            startAudioSession()

            #if DEBUG
            print("🟢 AUDIO VIEW - iOS platform detected")
            print("AudioMemorizationView: fontFamily from settings = '\(fontFamily)'")
            print("AudioMemorizationView: font exists? \(UIFont(name: fontFamily, size: 12) != nil)")
            #endif
        }
        .onDisappear {
            stopAudioSession()
        }
        #else
        // macOS: Keep original layout without ScrollView
        return VStack(spacing: 20) {
            // Header
            headerView

            if !audioService.isNetworkAvailable() {
                networkWarningView
            }

            // Main Content
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if !pageVerses.isEmpty {
                // Current verse display
                currentVerseView

                // Progress indicator
                progressView
                    .padding(.top, 10)

                // Controls
                controlsView
                    .padding(.top, 10)
            }
        }
        .padding()
        .onAppear {
            print("🟢 AUDIO VIEW ON APPEAR - Starting session")
            startAudioSession()

            #if DEBUG
            print("🟢 AUDIO VIEW - macOS platform detected")
            verifyFontOnMacOS()
            #endif
        }
        .onDisappear {
            stopAudioSession()
        }
        #endif
    }

    // MARK: - View Components

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                    Text("Exit Audio Mode")
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            Text("Page \(currentPage)")
                .font(.headline)
        }
        .padding(.horizontal)
    }

    private var networkWarningView: some View {
        HStack {
            Image(systemName: "wifi.exclamationmark")
                .foregroundColor(.orange)
            Text("No Internet Connection")
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading audio...")
                .padding(.top)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text(error)
                .multilineTextAlignment(.center)
                .padding()
            Button("Retry") {
                errorMessage = nil
                fetchAndPlayCurrentVerse()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var currentVerseView: some View {
        VStack(spacing: 10) {
            if currentVerseIndex < pageVerses.count {
                let verse = pageVerses[currentVerseIndex]

                let _ = print("🟡 RENDERING VERSE: \(verse.surah):\(verse.ayah), words count: \(verse.words.count)")

                // Surah and Ayah number
                Text("Surah \(verse.surah), Ayah \(verse.ayah)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Arabic text - render words individually with QPC font
                // IMPORTANT: Wrap in ScrollView with max height to prevent pushing controls off screen
                if verse.words.isEmpty {
                    Text("No text available")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(15)
                } else {
                    // Get the correct QPC font for this page
                    let pageFontName = "QCF_P\(String(format: "%03d", currentPage))"

                    // Wrap verse text in ScrollView with max height
                    ScrollView {
                        // Render words in RTL horizontal flow
                        FlowLayout(spacing: 8) {
                            ForEach(verse.words, id: \.id) { word in
                                #if os(macOS)
                                // macOS: Use NSFont directly
                                if let nsFont = NSFont(name: pageFontName, size: CGFloat(fontSize)) {
                                    Text(word.text)
                                        .font(Font(nsFont))
                                } else {
                                    Text(word.text)
                                        .font(.system(size: CGFloat(fontSize)))
                                }
                                #else
                                // iOS: Use custom font
                                Text(word.text)
                                    .font(.custom(pageFontName, size: CGFloat(fontSize)))
                                #endif
                            }
                        }
                        .frame(maxWidth: .infinity) // no trailing alignment; FlowLayout handles RTL placement
                        .padding()
                    }
                    .frame(maxHeight: 300) // Constrain height to keep controls visible
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                }

                // Status indicator
                if audioPlayer.isPracticePause {
                    Label("Practice Time", systemImage: "mic.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                }
            }
        }
        .padding(.horizontal)
    }

    private var progressView: some View {
        VStack(spacing: 10) {
            // Verse progress on page
            HStack {
                Text("Verse \(currentVerseIndex + 1) of \(pageVerses.count)")
                    .font(.caption)
                Spacer()
                if audioPlayer.isPracticePause {
                    Text("Practice Pause")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)

                    if audioPlayer.duration > 0 {
                        // Clamp progress to 0...1 to prevent out-of-bounds rendering
                        let progress = min(max(audioPlayer.currentProgress / audioPlayer.duration, 0), 1)
                        Rectangle()
                            .fill(audioPlayer.isPracticePause ? Color.green : Color.blue)
                            .frame(
                                width: geometry.size.width * progress,
                                height: 8
                            )
                            .cornerRadius(4)
                    }
                }
            }
            .frame(height: 8)

            // Page progress dots
            HStack(spacing: 8) {
                ForEach(0..<pageVerses.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentVerseIndex ? Color.blue :
                              index < currentVerseIndex ? Color.green :
                              Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal)
    }

    private var controlsView: some View {
        HStack(spacing: 40) {
            // Previous button
            Button(action: previousVerse) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 30))
            }
            .disabled(currentVerseIndex == 0)
            .foregroundColor(currentVerseIndex == 0 ? .gray : .primary)

            // Main play/pause button
            Button(action: togglePlayPause) {
                ZStack {
                    Circle()
                        .fill(audioPlayer.isPlaying || audioPlayer.isPracticePause ? Color.red : Color.green)
                        .frame(width: 120, height: 120)

                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" :
                          audioPlayer.isPracticePause ? "forward.fill" :
                          "play.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
            }

            // Next button
            Button(action: nextVerse) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 30))
            }
            .disabled(currentVerseIndex >= pageVerses.count - 1 && !audioPlayer.isPracticePause)
            .foregroundColor(currentVerseIndex >= pageVerses.count - 1 && !audioPlayer.isPracticePause ? .gray : .primary)
        }
        .padding()
    }

    // MARK: - Actions

    private func startAudioSession() {
        if !pageVerses.isEmpty {
            fetchAndPlayCurrentVerse()
        }
    }

    private func stopAudioSession() {
        isSessionActive = false
        audioPlayer.stop()
    }

    private func togglePlayPause() {
        if audioPlayer.isPracticePause {
            // Skip practice pause and move to next verse
            audioPlayer.skipPracticePause()
            nextVerse()
        } else if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            fetchAndPlayCurrentVerse()
        }
    }

    private func previousVerse() {
        guard currentVerseIndex > 0 else { return }
        // Stop audio immediately to prevent race conditions
        audioPlayer.stop()
        currentVerseIndex -= 1
        fetchAndPlayCurrentVerse()
    }

    private func nextVerse() {
        // CRITICAL: Stop audio immediately to prevent race conditions
        // This stops old audio callbacks from updating the progress bar
        audioPlayer.stop()

        if currentVerseIndex < pageVerses.count - 1 {
            // More verses on current page
            currentVerseIndex += 1
            fetchAndPlayCurrentVerse()
        } else if isSessionActive && currentPage < 604 {
            // End of page - auto-advance to next page
            print("📄 Auto-advancing from page \(currentPage) to \(currentPage + 1)")

            // Fetch new page data from parent via callback
            let nextPageNumber = currentPage + 1
            let newPageWords = onPageAdvance(nextPageNumber)

            // Update page number (this is the only place we increment it)
            currentPage = nextPageNumber
            currentVerseIndex = 0

            // Update page data
            pageWords = newPageWords
            pageVerses = Self.buildPageVerses(from: newPageWords)

            // Continue playback with first verse of new page
            if !pageVerses.isEmpty {
                fetchAndPlayCurrentVerse()
            } else {
                errorMessage = "No verses found on page \(currentPage)"
            }
        } else {
            // End of Quran or session ended
            let message = currentPage >= 604 ? "End of Quran reached" : "Session ended"
            errorMessage = message
            print("🏁 \(message)")
        }
    }

    private func fetchAndPlayCurrentVerse() {
        guard currentVerseIndex < pageVerses.count else { return }
        guard audioService.isNetworkAvailable() else {
            errorMessage = "No internet connection"
            return
        }

        let verse = pageVerses[currentVerseIndex]
        isLoading = true
        errorMessage = nil

        // Fetch audio from API
        audioService.fetchVerseAudio(surah: verse.surah, ayah: verse.ayah) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let cachedVerse):
                    // Start playback
                    playVerse(audioURL: cachedVerse.audioURL)

                    // Prefetch next verse if available
                    if currentVerseIndex < pageVerses.count - 1 {
                        let nextVerse = pageVerses[currentVerseIndex + 1]
                        audioService.prefetchNextVerse(
                            currentSurah: verse.surah,
                            currentAyah: verse.ayah,
                            totalAyahsInSurah: getTotalAyahs(forSurah: verse.surah)
                        )
                    }

                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func playVerse(audioURL: URL) {
        let startTime = Date()

        audioPlayer.play(url: audioURL) { [weak audioPlayer] in
            // Audio finished playing
            guard let player = audioPlayer else { return }

            let playbackDuration = Date().timeIntervalSince(startTime)

            // Start practice pause with same duration
            player.startPracticePause(duration: playbackDuration) {
                // Practice pause finished, auto-advance if session is active
                if isSessionActive {
                    DispatchQueue.main.async {
                        nextVerse()
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func getTotalAyahs(forSurah surah: Int) -> Int {
        // This should ideally come from your SurahInfo data
        // For now, returning a default value
        // You can integrate with your existing SurahInfo.swift
        switch surah {
        case 1: return 7    // Al-Fatiha
        case 2: return 286  // Al-Baqarah
        case 3: return 200  // Al-Imran
        // Add more as needed or integrate with SurahInfo
        default: return 100 // Default fallback
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AudioMemorizationView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }

    struct PreviewWrapper: View {
        @State private var currentPage = 1

        var body: some View {
            let sampleWords = [
                QuranWord(id: 1, location: "1:1:1", surah: 1, ayah: 1, word: 1, text: "بِسْمِ"),
                QuranWord(id: 2, location: "1:1:2", surah: 1, ayah: 1, word: 2, text: "ٱللَّهِ"),
                QuranWord(id: 3, location: "1:1:3", surah: 1, ayah: 1, word: 3, text: "ٱلرَّحْمَـٰنِ"),
                QuranWord(id: 4, location: "1:1:4", surah: 1, ayah: 1, word: 4, text: "ٱلرَّحِيمِ")
            ]
            let pageWords = [(line: 1, words: sampleWords)]

            AudioMemorizationView(
                currentPage: $currentPage,
                pageWords: pageWords,
                onPageAdvance: { nextPage in
                    // Preview stub - return empty data
                    return []
                }
            )
        }
    }
}
#endif
