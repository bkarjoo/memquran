import SwiftUI
import AVFoundation

#if os(macOS)
import AppKit
#else
import UIKit
import AudioToolbox
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
    @State private var currentSegmentIndex = 0
    @State private var versePauseData: [Int: VersePauseData] = [:]
    @State private var pageWords: [(line: Int, words: [QuranWord])] = []
    @State private var pageVerses: [(surah: Int, ayah: Int, words: [QuranWord])] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var audioPlaybackDuration: TimeInterval = 0
    @State private var isSessionActive = true
    @Binding var currentPage: Int

    // Pause detection tuning (temporary for experimentation)
    @State private var silenceThreshold: Double = 15  // 15% (shown as 15, converted to 0.15)
    @State private var minimumPauseDuration: Double = 300  // 300ms (shown as 300, converted to 0.3s)
    @State private var showDetectionSettings = false

    let onPageAdvance: (Int) -> [(line: Int, words: [QuranWord])]

    @Environment(\.dismiss) private var dismiss

    // Settings from AppStorage (matching what Settings uses)
    @AppStorage("fontSize") private var fontSize: Double = 28
    @AppStorage("lineHeightMultiplier") private var lineHeightMultiplier: Double = 2.2
    @AppStorage("fontFamily") private var fontFamily: String = "ScheherazadeNew-Regular"

    // Pause duration mode (Learning vs Review)
    @AppStorage("pauseDurationMode") private var pauseDurationMode: PauseDurationMode = .learning

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
        #if os(iOS)
        // iOS: Use a fixed layout that ensures controls are always visible
        return VStack(spacing: 0) {
            // Header
            headerView

            if !audioService.isNetworkAvailable() {
                networkWarningView
            }

            // Detection settings panel
            if showDetectionSettings {
                detectionSettingsView
            }

            // Pause mode selection (always visible)
            pauseModeSelectionView

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

            // Detection settings panel
            if showDetectionSettings {
                detectionSettingsView
            }

            // Pause mode selection (always visible)
            pauseModeSelectionView

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
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Page \(currentPage)")
                .font(.headline)

            Spacer()

            Button(action: { showDetectionSettings.toggle() }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(showDetectionSettings ? .blue : .secondary)
            }
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

    private var detectionSettingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pause Detection Settings")
                .font(.headline)

            HStack {
                Text("Sensitivity (%):")
                    .font(.caption)
                #if os(iOS)
                TextField("15", value: $silenceThreshold, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                #else
                TextField("15", value: $silenceThreshold, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                #endif
            }

            HStack {
                Text("Min Duration (ms):")
                    .font(.caption)
                #if os(iOS)
                TextField("300", value: $minimumPauseDuration, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                #else
                TextField("300", value: $minimumPauseDuration, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                #endif
            }

            Button(action: reanalyzeCurrentVerse) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Re-analyze Current Verse")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || currentVerseIndex >= pageVerses.count)

            Button(action: clearAllPauseData) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Clear All Pause Data")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var pauseModeSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Pause Duration Mode", selection: $pauseDurationMode) {
                Label("Learning", systemImage: "ear")
                    .tag(PauseDurationMode.learning)
                Label("Review", systemImage: "mic")
                    .tag(PauseDurationMode.review)
            }
            .pickerStyle(.segmented)
            .disabled(audioPlayer.isPlaying || audioPlayer.isPracticePause)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                    if audioPlayer.currentPauseNumber > 0 {
                        // Micro-pause indicator
                        Label("Pause \(audioPlayer.currentPauseNumber) of \(audioPlayer.totalPauses)", systemImage: "pause.circle.fill")
                            .foregroundColor(.orange)
                            .font(.headline)
                    } else {
                        // End-of-verse practice pause (only in learning mode)
                        Label("Practice Time", systemImage: "mic.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                    }
                }

                // Edge case message for final segment in review mode
                if !audioPlayer.isPracticePause && audioPlayer.isPlaying {
                    let isLastSegment = (audioPlayer.currentPauseNumber == audioPlayer.totalPauses - 1)
                    if isLastSegment && pauseDurationMode == .review && audioPlayer.totalPauses > 1 {
                        Text("Final phrase - session will end after playback")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
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
                    if audioPlayer.currentPauseNumber > 0 {
                        Text("Pause \(audioPlayer.currentPauseNumber)/\(audioPlayer.totalPauses)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("Practice Pause")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else if audioPlayer.totalPauses > 0 {
                    Text("\(audioPlayer.totalPauses) pauses")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

                        // Color based on state: orange for micro-pause, green for practice pause, blue for playing
                        let barColor: Color = {
                            if audioPlayer.isPracticePause && audioPlayer.currentPauseNumber > 0 {
                                return .orange  // Micro-pause
                            } else if audioPlayer.isPracticePause {
                                return .green   // End-of-verse practice pause
                            } else {
                                return .blue    // Playing audio
                            }
                        }()

                        Rectangle()
                            .fill(barColor)
                            .frame(
                                width: geometry.size.width * progress,
                                height: 8
                            )
                            .cornerRadius(4)
                    }
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal)
    }

    private var controlsView: some View {
        HStack(spacing: 40) {
            // Previous button (segment-pair navigation)
            Button(action: previous) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 30))
            }
            .disabled(currentPage == 1 && currentVerseIndex == 0 && currentSegmentIndex == 0)
            .foregroundColor((currentPage == 1 && currentVerseIndex == 0 && currentSegmentIndex == 0) ? .gray : .primary)

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

            // Next button (segment-pair navigation)
            Button(action: next) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 30))
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func startAudioSession() {
        if !pageVerses.isEmpty {
            // Reset segment tracking for new session
            currentSegmentIndex = 0
            currentVerseIndex = 0
            versePauseData.removeAll()

            // Don't auto-start playback - wait for user to press play
            print("🟢 Audio session initialized - ready to play")
        }
    }

    private func stopAudioSession() {
        isSessionActive = false
        audioPlayer.stop()
    }

    private func togglePlayPause() {
        if audioPlayer.isPracticePause {
            // Skip practice pause - this will trigger completion handler which calls next()
            audioPlayer.skipPracticePause()
        } else if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            // Play beep if in review mode
            if pauseDurationMode == .review {
                #if os(iOS)
                AudioServicesPlaySystemSound(1052)
                #elseif os(macOS)
                NSSound.beep()
                #endif
            }

            // Resume or start current segment pair
            playCurrentSegmentPair()
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

    // MARK: - Segment-Pair Navigation (Clean Architecture)

    /// Filter pauses using same logic as AudioPlayer (except duration boundary check)
    private func filterPauses(_ pauses: [PauseTimestamp]) -> [PauseTimestamp] {
        // Filter: confidence >= 0.7, duration >= 0.3s
        let filtered = pauses.filter { pause in
            pause.confidence >= 0.7 && pause.duration >= 0.3
        }

        // Limit to max 5 pauses (take most confident ones)
        let sorted = filtered.sorted { $0.confidence > $1.confidence }
        let limited = Array(sorted.prefix(5))

        // Re-sort by time for playback order
        return limited.sorted { $0.startTime < $1.startTime }
    }

    /// Calculate number of segment pairs in a verse
    /// A verse with N pauses has N+1 segment pairs (including the final segment)
    private func segmentPairCount(for verseIndex: Int) -> Int {
        guard let pauseData = versePauseData[verseIndex] else {
            return 1  // No pause data = 1 segment pair
        }
        // IMPORTANT: Use filtered pauses (same as AudioPlayer, minus duration check)
        let filteredPauses = filterPauses(pauseData.pauses)
        return filteredPauses.count + 1
    }

    /// Clean next function - always jump to next segment pair
    private func next() {
        audioPlayer.stop()

        let oldSegment = currentSegmentIndex
        let oldVerse = currentVerseIndex

        currentSegmentIndex += 1

        // Check if we need to move to next verse
        let segmentCount = segmentPairCount(for: currentVerseIndex)
        print("🔵 NEXT: verse \(currentVerseIndex), segment \(oldSegment) → \(currentSegmentIndex), segmentCount=\(segmentCount)")

        if currentSegmentIndex >= segmentCount {
            currentVerseIndex += 1
            currentSegmentIndex = 0
            print("   ➡️ Moving to next verse: \(oldVerse) → \(currentVerseIndex)")

            // Check if we need to move to next page
            if currentVerseIndex >= pageVerses.count {
                if currentPage < 604 {
                    // Advance to next page
                    let nextPageNumber = currentPage + 1
                    let newPageWords = onPageAdvance(nextPageNumber)

                    currentPage = nextPageNumber
                    currentVerseIndex = 0
                    currentSegmentIndex = 0

                    pageWords = newPageWords
                    pageVerses = Self.buildPageVerses(from: newPageWords)

                    if pageVerses.isEmpty {
                        errorMessage = "No verses found on page \(currentPage)"
                        return
                    }
                    print("   📄 Advanced to page \(currentPage)")
                } else {
                    // End of Quran
                    errorMessage = "End of Quran reached"
                    return
                }
            }
        }

        // Capture values to prevent race conditions
        let targetVerse = currentVerseIndex
        let targetSegment = currentSegmentIndex
        print("   ▶️ Playing verse \(targetVerse), segment \(targetSegment)")
        playSegmentPair(verseIndex: targetVerse, segmentIndex: targetSegment)
    }

    /// Clean previous function - segment-pair aware
    private func previous() {
        // Capture isPracticePause BEFORE stopping (stop() resets it to false)
        let wasInPause = audioPlayer.isPracticePause
        audioPlayer.stop()

        if wasInPause {
            // In pause → restart current segment pair
            let targetVerse = currentVerseIndex
            let targetSegment = currentSegmentIndex
            playSegmentPair(verseIndex: targetVerse, segmentIndex: targetSegment)
        } else {
            // In audio → go to previous segment pair
            currentSegmentIndex -= 1

            if currentSegmentIndex < 0 {
                // Need to move to previous verse
                currentVerseIndex -= 1

                if currentVerseIndex < 0 {
                    if currentPage > 1 {
                        // Move to previous page
                        let prevPageNumber = currentPage - 1
                        let newPageWords = onPageAdvance(prevPageNumber)

                        currentPage = prevPageNumber
                        pageWords = newPageWords
                        pageVerses = Self.buildPageVerses(from: newPageWords)

                        // Go to last verse of previous page
                        currentVerseIndex = max(0, pageVerses.count - 1)

                        // Fetch pause data to get correct last segment index
                        Task {
                            await loadPauseDataAndGoToLastSegment(verseIndex: self.currentVerseIndex)
                        }
                        return
                    } else {
                        // Beginning of Quran - stay at beginning
                        currentVerseIndex = 0
                        currentSegmentIndex = 0
                        playSegmentPair(verseIndex: 0, segmentIndex: 0)
                        return
                    }
                } else {
                    // Go to last segment of previous verse
                    // Fetch pause data to get correct last segment index
                    Task {
                        await loadPauseDataAndGoToLastSegment(verseIndex: self.currentVerseIndex)
                    }
                    return
                }
            }

            // Staying in current verse, just different segment
            let targetVerse = currentVerseIndex
            let targetSegment = currentSegmentIndex
            playSegmentPair(verseIndex: targetVerse, segmentIndex: targetSegment)
        }
    }

    /// Helper to load pause data and navigate to last segment of specific verse
    private func loadPauseDataAndGoToLastSegment(verseIndex: Int) async {
        guard verseIndex < pageVerses.count else { return }

        let verse = pageVerses[verseIndex]

        // Fetch audio to get edition info
        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: verse.surah, ayah: verse.ayah) { result in
                continuation.resume()

                if case .success(let cachedVerse) = result {
                    Task {
                        // Load pause data
                        let pauseStore = PauseDataStore.shared
                        if let pauseData = await pauseStore.getPauseData(
                            edition: cachedVerse.edition,
                            surah: cachedVerse.surah,
                            ayah: cachedVerse.ayah
                        ) {
                            // Cache it
                            await MainActor.run {
                                self.versePauseData[verseIndex] = pauseData
                                // Calculate the correct last segment
                                let lastSegment = max(0, pauseData.pauses.count)  // pauses.count is the last segment index
                                self.currentSegmentIndex = lastSegment
                                self.playSegmentPair(verseIndex: verseIndex, segmentIndex: lastSegment)
                            }
                        } else {
                            // No pause data - only one segment (segment 0)
                            await MainActor.run {
                                self.currentSegmentIndex = 0
                                self.playSegmentPair(verseIndex: verseIndex, segmentIndex: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Play a specific segment pair (with explicit parameters to avoid race conditions)
    private func playSegmentPair(verseIndex: Int, segmentIndex: Int) {
        guard verseIndex < pageVerses.count else { return }
        guard audioService.isNetworkAvailable() else {
            errorMessage = "No internet connection"
            return
        }

        let verse = pageVerses[verseIndex]
        isLoading = true
        errorMessage = nil

        print("🎬 playSegmentPair: verse=\(verseIndex) (surah:\(verse.surah), ayah:\(verse.ayah)), segment=\(segmentIndex)")

        // Fetch audio and pause data, then play at specific segment
        audioService.fetchVerseAudio(surah: verse.surah, ayah: verse.ayah) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let cachedVerse):
                    Task {
                        // Ensure pause data is analyzed and cached
                        await self.analyzePauseDataIfNeeded(cachedVerse: cachedVerse)

                        // Get pause data for this verse
                        let pauseStore = PauseDataStore.shared
                        if let pauseData = await pauseStore.getPauseData(
                            edition: cachedVerse.edition,
                            surah: cachedVerse.surah,
                            ayah: cachedVerse.ayah
                        ) {
                            // Cache it for segment counting
                            await MainActor.run {
                                self.versePauseData[verseIndex] = pauseData
                                print("   💾 Cached pause data for verse \(verseIndex): \(pauseData.pauses.count) pauses = \(pauseData.pauses.count + 1) segments")
                            }
                        } else {
                            print("   ⚠️ No pause data found for verse \(verseIndex)")
                        }

                        // Start playback at specific segment
                        await MainActor.run {
                            self.playVerseAtSegment(cachedVerse: cachedVerse, startSegment: segmentIndex)
                        }
                    }

                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Play the current segment pair (clean entry point)
    private func playCurrentSegmentPair() {
        playSegmentPair(verseIndex: currentVerseIndex, segmentIndex: currentSegmentIndex)
    }


    /// Legacy function (kept for compatibility, redirects to new system)
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
                    // Check/analyze pause data before playback (Phase 2)
                    // IMPORTANT: Wait for analysis to complete before starting playback
                    Task {
                        await self.analyzePauseDataIfNeeded(cachedVerse: cachedVerse)

                        // Start playback (Phase 3: with pause data)
                        // Note: Prefetching happens during practice pause (see playVerse method)
                        await MainActor.run {
                            self.playVerse(cachedVerse: cachedVerse)
                        }
                    }

                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Phase 2: Check if pause data exists, analyze if not
    private func analyzePauseDataIfNeeded(cachedVerse: CachedAudioVerse, forceReanalyze: Bool = false) async {
        let pauseStore = PauseDataStore.shared
        let edition = cachedVerse.edition

        // Check if pause data already exists
        if !forceReanalyze, let existingData = await pauseStore.getPauseData(edition: edition, surah: cachedVerse.surah, ayah: cachedVerse.ayah) {
            print("✅ Pause data found: \(existingData.pauses.count) pauses for \(edition):\(cachedVerse.surah):\(cachedVerse.ayah)")
            return
        }

        // No pause data found - analyze the audio file
        print("🔍 \(forceReanalyze ? "Re-analyzing" : "Analyzing") audio for \(edition):\(cachedVerse.surah):\(cachedVerse.ayah)")

        // Convert UI values to proper units
        let thresholdFraction = Float(silenceThreshold / 100.0)  // 15 -> 0.15
        let durationSeconds = minimumPauseDuration / 1000.0  // 300 -> 0.3

        print("   Settings: threshold=\(thresholdFraction), minDuration=\(durationSeconds)s")

        do {
            let pauseService = PauseDetectionService()

            // Create custom config with user's settings
            let config = PauseDetectionService.DetectionConfig(
                silenceThresholdFraction: thresholdFraction,
                minimumPauseDuration: durationSeconds
            )

            let pauses = try await pauseService.analyzePauses(audioURL: cachedVerse.audioURL, config: config)

            // Create and save pause data (even if empty - that's a valid result)
            let pauseData = VersePauseData(
                edition: edition,
                surah: cachedVerse.surah,
                ayah: cachedVerse.ayah,
                pauses: pauses,
                detectionVersion: 1
            )

            await pauseStore.savePauseData(pauseData)
            print("💾 Saved pause data: \(pauses.count) pauses detected for \(edition):\(cachedVerse.surah):\(cachedVerse.ayah)")
        } catch {
            // Don't persist on failure - allow retry on next playback
            print("⚠️ Pause detection failed for \(edition):\(cachedVerse.surah):\(cachedVerse.ayah): \(error)")
            print("   Will retry analysis on next playback")
        }
    }

    /// Re-analyze current verse with new detection settings
    private func reanalyzeCurrentVerse() {
        guard currentVerseIndex < pageVerses.count else { return }

        // Stop current playback
        audioPlayer.stop()

        // Get current verse info
        let verse = pageVerses[currentVerseIndex]

        // Fetch audio and force re-analyze
        isLoading = true
        audioService.fetchVerseAudio(surah: verse.surah, ayah: verse.ayah) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let cachedVerse):
                    // Force re-analysis with new settings, wait for completion
                    Task {
                        await self.analyzePauseDataIfNeeded(cachedVerse: cachedVerse, forceReanalyze: true)

                        // Start playback with new pause data
                        await MainActor.run {
                            self.playVerse(cachedVerse: cachedVerse)
                        }
                    }

                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Clear all cached pause data (debug/nuclear option)
    private func clearAllPauseData() {
        Task {
            let pauseStore = PauseDataStore.shared
            await pauseStore.clearAllPauseData()

            await MainActor.run {
                // Clear cached data
                versePauseData.removeAll()
                print("🗑️ All pause data cleared")
            }
        }
    }

    /// Play verse starting at a specific segment index
    private func playVerseAtSegment(cachedVerse: CachedAudioVerse, startSegment: Int) {
        let currentVerse = pageVerses[currentVerseIndex]

        Task {
            let pauseStore = PauseDataStore.shared
            let pauseData = await pauseStore.getPauseData(
                edition: cachedVerse.edition,
                surah: cachedVerse.surah,
                ayah: cachedVerse.ayah
            )

            let pauses = pauseData?.pauses ?? []

            // Start playback with segment info
            await MainActor.run {
                // Set pause duration mode before playback
                audioPlayer.pauseDurationMode = pauseDurationMode

                audioPlayer.play(
                    url: cachedVerse.audioURL,
                    pauses: pauses,
                    segmentIndex: startSegment
                ) { nextSegment in
                    // Segment pair complete - nextSegment is nil if this was the last segment
                    if let next = nextSegment {
                        // More segments to play
                        print("✅ Segment \(startSegment) complete, advancing to segment \(next)")
                        self.currentSegmentIndex = next
                        // Play next segment
                        self.playVerseAtSegment(cachedVerse: cachedVerse, startSegment: next)
                    } else {
                        // All segments complete (last segment finished) - move to next verse
                        print("✅ All segments complete for this verse")
                        self.audioService.prefetchLookahead(currentSurah: currentVerse.surah, currentAyah: currentVerse.ayah)

                        if self.isSessionActive {
                            DispatchQueue.main.async {
                                // Move to next verse (don't increment segment - AudioPlayer already handled that)
                                let oldVerse = self.currentVerseIndex
                                self.currentVerseIndex += 1
                                self.currentSegmentIndex = 0
                                print("   ➡️ Verse complete, moving to next verse: \(oldVerse) → \(self.currentVerseIndex)")

                                // Check if we need to move to next page
                                if self.currentVerseIndex >= self.pageVerses.count {
                                    if self.currentPage < 604 {
                                        // Advance to next page
                                        let nextPageNumber = self.currentPage + 1
                                        let newPageWords = self.onPageAdvance(nextPageNumber)

                                        self.currentPage = nextPageNumber
                                        self.currentVerseIndex = 0
                                        self.currentSegmentIndex = 0

                                        self.pageWords = newPageWords
                                        self.pageVerses = Self.buildPageVerses(from: newPageWords)

                                        if self.pageVerses.isEmpty {
                                            self.errorMessage = "No verses found on page \(self.currentPage)"
                                            return
                                        }
                                        print("   📄 Advanced to page \(self.currentPage)")
                                    } else {
                                        // End of Quran
                                        self.errorMessage = "End of Quran reached"
                                        return
                                    }
                                }

                                // Play first segment of next verse
                                self.playCurrentSegmentPair()
                            }
                        }
                    }
                }
            }
        }
    }

    /// Legacy function (kept for compatibility)
    private func playVerse(cachedVerse: CachedAudioVerse) {
        let currentVerse = pageVerses[currentVerseIndex]

        // Phase 3: Fetch pause data for this verse
        Task {
            let pauseStore = PauseDataStore.shared
            let pauseData = await pauseStore.getPauseData(
                edition: cachedVerse.edition,
                surah: cachedVerse.surah,
                ayah: cachedVerse.ayah
            )

            let pauses = pauseData?.pauses ?? []
            if pauses.count > 0 {
                print("🎵 Playing verse with \(pauses.count) pauses available")
            }

            // IMPORTANT: Cache pause data for segment counting
            await MainActor.run {
                if let pauseData = pauseData {
                    self.versePauseData[self.currentVerseIndex] = pauseData
                }
            }

            // Start playback from segment 0 (this is the legacy path - just delegates to playVerseAtSegment)
            await MainActor.run {
                self.playVerseAtSegment(cachedVerse: cachedVerse, startSegment: 0)
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
