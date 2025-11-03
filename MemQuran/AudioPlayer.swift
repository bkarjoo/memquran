import Foundation
import AVFoundation
import Combine
#if os(iOS)
import AudioToolbox
#endif

/// Manages audio playback for Quran verse recitation
@MainActor
class AudioPlayer: ObservableObject {
    // MARK: - Published Properties

    @Published var isPlaying = false
    @Published var isPracticePause = false
    @Published var currentProgress: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var errorMessage: String?
    @Published var isInterrupted = false

    // Phase 3: Pause visualization
    @Published var totalPauses: Int = 0
    @Published var currentPauseNumber: Int = 0  // 1-indexed for display

    // Pause duration mode (Learning vs Review)
    var pauseDurationMode: PauseDurationMode = .learning

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var practicePauseTimer: Timer?
    private var completionHandler: (() -> Void)?

    // Store actual audio file duration (never overwrite this!)
    private var audioFileDuration: Double = 0.0

    // Phase 3: Unified segment-based pause system
    private var versePauses: [PauseTimestamp] = []
    private var nextPauseIndex: Int = 0
    private var isInMicroPause = false
    private var pauseBeforeResuming: CMTime?  // Save playback position before micro-pause
    private var segmentStartTime: TimeInterval = 0.0  // Track when current segment started
    private var isLastSegment: Bool = false  // Track if current pause is the final one

    // Interruption handling
    private var wasPlayingBeforeInterruption = false
    private var wasInPracticePauseBeforeInterruption = false
    private var practicePauseRemainingDuration: TimeInterval = 0
    private var practicePauseStartTime: Date?
    private var practicePauseCompletionHandler: (() -> Void)?
    private var isSessionActive = true  // Track if session was intentionally stopped
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?

    // Serial execution guard
    private var isPreparingToPlay = false

    // MARK: - Singleton (optional, can be instantiated per view)

    static let shared = AudioPlayer()

    // MARK: - Initialization

    init() {
        setupAudioSession()
    }

    deinit {
        // Remove audio session observers using stored tokens
        // This is safe to call from deinit since we're using tokens
        #if os(iOS)
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = mediaResetObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)

            // Register for audio interruption notifications (only if not already registered)
            if interruptionObserver == nil {
                interruptionObserver = NotificationCenter.default.addObserver(
                    forName: AVAudioSession.interruptionNotification,
                    object: AVAudioSession.sharedInstance(),
                    queue: .main
                ) { [weak self] notification in
                    // Already on main queue, no need for Task { @MainActor in }
                    self?.handleInterruption(notification)
                }
            }

            // Register for route change notifications (CarPlay, headphones, etc.)
            if routeChangeObserver == nil {
                routeChangeObserver = NotificationCenter.default.addObserver(
                    forName: AVAudioSession.routeChangeNotification,
                    object: AVAudioSession.sharedInstance(),
                    queue: .main
                ) { [weak self] notification in
                    // Already on main queue, no need for Task { @MainActor in }
                    self?.handleRouteChange(notification)
                }
            }

            // Register for media services reset notification (rare but critical)
            if mediaResetObserver == nil {
                mediaResetObserver = NotificationCenter.default.addObserver(
                    forName: AVAudioSession.mediaServicesWereResetNotification,
                    object: AVAudioSession.sharedInstance(),
                    queue: .main
                ) { [weak self] notification in
                    // Already on main queue, no need for Task { @MainActor in }
                    self?.handleMediaServicesReset()
                }
            }
            #endif
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Public Methods

    /// Play audio from URL with optional pause detection
    /// - Parameters:
    ///   - url: Audio file URL
    ///   - pauses: Optional array of detected pause timestamps for segment pauses
    ///   - startAtSegment: Which segment pair to start at (0-based, default 0)
    ///   - completion: Called when ALL segments complete (including final segment pause)
    func play(url: URL, pauses: [PauseTimestamp] = [], startAtSegment: Int = 0, completion: (() -> Void)? = nil) {
        guard !isPreparingToPlay else {
            print("⚠️ Ignoring play() - already preparing")
            return
        }
        isPreparingToPlay = true

        cleanup()

        completionHandler = completion
        isSessionActive = true

        // Create player item and player to get duration first
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        print("🔍 DEBUG: Loading audio from URL: \(url.lastPathComponent)")
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            print("🔍 DEBUG: File size: \(fileSize) bytes (\(fileSize / 1024) KB)")
        }

        // Get total duration
        guard let item = playerItem else {
            isPreparingToPlay = false
            return
        }
        let totalDuration = CMTimeGetSeconds(item.asset.duration)
        print("🔍 DEBUG: totalDuration = \(totalDuration)")

        // Store the audio file duration separately (never overwrite this!)
        audioFileDuration = totalDuration
        self.duration = totalDuration

        // Filter and store pauses with duration check
        versePauses = filterPauses(pauses, duration: totalDuration)
        print("🔍 DEBUG: Filtered \(pauses.count) pauses to \(versePauses.count)")
        currentSegmentIndex = startAtSegment
        totalPauses = versePauses.count + 1  // +1 for final segment

        if versePauses.count > 0 {
            print("🎯 Playing with \(versePauses.count) detected pauses + 1 final segment = \(totalPauses) total segments")
        } else {
            print("🎯 Playing as single segment (no pauses detected)")
        }

        // Reactivate audio session if it was deactivated by stop()
        #if os(iOS)
        if !reactivateAudioSession() {
            isPreparingToPlay = false
            return
        }
        #endif

        // No need for end-of-file observer - we use boundary observers for each segment

        // Start playing segments
        isPreparingToPlay = false
        playNextSegment()
    }

    private var currentSegmentIndex = 0

    private func playNextSegment() {
        guard isSessionActive else { return }

        // LOG: Current state - USE audioFileDuration for calculations (never self.duration!)
        print("📊 SEGMENT CALC: currentSegmentIndex=\(currentSegmentIndex), versePauses.count=\(versePauses.count), audioFileDuration=\(audioFileDuration)")

        // LOG: Pause data
        for (i, pause) in versePauses.enumerated() {
            print("   Pause \(i): start=\(String(format: "%.2f", pause.startTime)), end=\(String(format: "%.2f", pause.endTime))")
        }

        // Calculate segment boundaries
        let segmentStart: TimeInterval
        let segmentEnd: TimeInterval
        let segmentDuration: TimeInterval

        if currentSegmentIndex == 0 {
            // First segment: 0 → first pause (or end)
            segmentStart = 0
            segmentEnd = versePauses.isEmpty ? audioFileDuration : versePauses[0].startTime
            print("   📍 First segment: start=0, end=\(String(format: "%.2f", segmentEnd)) (first pause start or audioFileDuration)")
        } else if currentSegmentIndex <= versePauses.count {
            // Middle segments: previous pause end → next pause start (or end)
            segmentStart = versePauses[currentSegmentIndex - 1].endTime
            print("   📍 Segment start = pause[\(currentSegmentIndex - 1)].endTime = \(String(format: "%.2f", segmentStart))")

            if currentSegmentIndex < versePauses.count {
                segmentEnd = versePauses[currentSegmentIndex].startTime
                print("   📍 Segment end = pause[\(currentSegmentIndex)].startTime = \(String(format: "%.2f", segmentEnd))")
            } else {
                segmentEnd = audioFileDuration  // Final segment
                print("   📍 Segment end = audioFileDuration = \(String(format: "%.2f", segmentEnd)) (final segment)")
            }
        } else {
            // All segments complete
            print("✅ All segments complete")
            let handler = completionHandler
            completionHandler = nil
            handler?()
            return
        }

        segmentDuration = segmentEnd - segmentStart
        print("   📍 RESULT: segment \(currentSegmentIndex): \(String(format: "%.2f", segmentStart))s → \(String(format: "%.2f", segmentEnd))s = \(String(format: "%.2f", segmentDuration))s duration")
        print("🎯 Segment \(currentSegmentIndex + 1)/\(totalPauses) | Duration: \(String(format: "%.2f", segmentDuration))s | Mode: \(pauseDurationMode == .learning ? "LEARNING" : "REVIEW")")

        if pauseDurationMode == .review {
            // Review mode: Pause → Play
            pauseThenPlay(duration: segmentDuration, start: segmentStart, end: segmentEnd)
        } else {
            // Learning mode: Play → Pause
            playThenPause(duration: segmentDuration, start: segmentStart, end: segmentEnd)
        }
    }

    private func pauseThenPlay(duration: TimeInterval, start: TimeInterval, end: TimeInterval) {
        // First: Pause for user to recite
        print("⏸️ Pause first (\(String(format: "%.2f", duration))s) - user recites")
        isPracticePause = true
        isPlaying = false
        currentProgress = 0.0
        self.duration = duration

        let startTime = Date()
        practicePauseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            self.currentProgress = elapsed

            if elapsed >= duration {
                // Then: Play segment
                self.practicePauseTimer?.invalidate()
                self.practicePauseTimer = nil
                self.isPracticePause = false
                self.currentProgress = 0.0
                self.playSegment(start: start, end: end)
            }
        }
    }

    private func playThenPause(duration: TimeInterval, start: TimeInterval, end: TimeInterval) {
        // First: Play segment
        playSegment(start: start, end: end)
    }

    private func playSegment(start: TimeInterval, end: TimeInterval) {
        print("▶️ Playing segment (\(String(format: "%.2f", start))s → \(String(format: "%.2f", end))s)")

        let segmentDuration = end - start
        self.duration = segmentDuration
        currentProgress = 0.0

        // Seek to start
        let startTime = CMTime(seconds: start, preferredTimescale: 600)
        player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)

        // Set boundary observer to stop at end
        let endTime = CMTime(seconds: end, preferredTimescale: 600)
        boundaryObserver = player?.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) { [weak self] in
            self?.onSegmentEnd()
        }

        // Add periodic time observer to track progress during playback
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentTime = CMTimeGetSeconds(time)
            let elapsed = currentTime - start
            self.currentProgress = max(0, min(elapsed, segmentDuration))
        }

        player?.play()
        isPlaying = true
    }

    private var boundaryObserver: Any?

    private func onSegmentEnd() {
        print("⏹️ Segment ended")

        // Remove observers
        if let observer = boundaryObserver {
            player?.removeTimeObserver(observer)
            boundaryObserver = nil
        }
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        player?.pause()
        isPlaying = false

        if pauseDurationMode == .learning {
            // Learning mode: Now pause after playing
            let segmentStart: TimeInterval
            let segmentEnd: TimeInterval

            if currentSegmentIndex == 0 {
                segmentStart = 0
                segmentEnd = versePauses.isEmpty ? audioFileDuration : versePauses[0].startTime
            } else if currentSegmentIndex <= versePauses.count {
                segmentStart = versePauses[currentSegmentIndex - 1].endTime
                if currentSegmentIndex < versePauses.count {
                    segmentEnd = versePauses[currentSegmentIndex].startTime
                } else {
                    segmentEnd = audioFileDuration
                }
            } else {
                return
            }

            let segmentDuration = segmentEnd - segmentStart
            print("⏸️ Pause after (\(String(format: "%.2f", segmentDuration))s) - user repeats")
            isPracticePause = true
            currentProgress = 0.0
            self.duration = segmentDuration

            let startTime = Date()
            practicePauseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                self.currentProgress = elapsed

                if elapsed >= segmentDuration {
                    self.practicePauseTimer?.invalidate()
                    self.practicePauseTimer = nil
                    self.isPracticePause = false
                    self.currentProgress = 0.0
                    self.currentSegmentIndex += 1
                    self.playNextSegment()
                }
            }
        } else {
            // Review mode: Already paused before, move to next segment
            currentSegmentIndex += 1
            playNextSegment()
        }
    }

    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Resume playback
    func resume() {
        player?.play()
        isPlaying = true
    }

    /// Stop playback completely
    func stop() {
        cleanup()

        // Also stop practice pause timer if active
        practicePauseTimer?.invalidate()
        practicePauseTimer = nil
        practicePauseCompletionHandler = nil
        practicePauseStartTime = nil

        // Phase 3: Reset pause state
        versePauses = []
        nextPauseIndex = 0
        isInMicroPause = false
        isLastSegment = false
        totalPauses = 0
        currentPauseNumber = 0
        pauseBeforeResuming = nil
        segmentStartTime = 0.0

        isPlaying = false
        isPracticePause = false
        currentProgress = 0.0
        duration = 0.0
        audioFileDuration = 0.0
        isSessionActive = false
        isPreparingToPlay = false

        // Deactivate audio session to be a good audio citizen
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🔇 Audio session deactivated")
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
        #endif
    }

    /// Start practice pause with same duration as the audio that just played
    func startPracticePause(duration: TimeInterval, completion: @escaping () -> Void) {
        isPracticePause = true
        isPlaying = false

        // Reset progress for practice pause
        currentProgress = 0.0
        self.duration = duration

        // Store completion handler for interruption recovery
        practicePauseCompletionHandler = completion

        // Track start time for interruption handling
        let startTime = Date()
        practicePauseStartTime = startTime

        // Create timer to track practice pause progress
        practicePauseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Already on main thread via RunLoop, no need for Task { @MainActor in }
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            self.currentProgress = elapsed

            if elapsed >= duration {
                self.practicePauseTimer?.invalidate()
                self.practicePauseTimer = nil
                self.isPracticePause = false
                self.currentProgress = 0.0
                self.practicePauseStartTime = nil
                let handler = self.practicePauseCompletionHandler
                self.practicePauseCompletionHandler = nil
                handler?()
            }
        }
    }

    /// Skip practice pause (both micro-pause and end-of-verse pause)
    func skipPracticePause() {
        practicePauseTimer?.invalidate()
        practicePauseTimer = nil
        isPracticePause = false
        currentProgress = 0.0
        practicePauseStartTime = nil

        // Phase 3: If skipping a micro-pause, resume playback
        if isInMicroPause {
            isInMicroPause = false
            currentPauseNumber = 0
            player?.play()
            isPlaying = true
        }
    }

    // MARK: - Private Methods

    // Obsolete methods removed - now using explicit segment loop approach

    /// Phase 3: Filter and limit pauses for better UX
    /// - Limit to max 5 pauses per verse
    /// - Only keep pauses with good confidence and reasonable duration
    /// - Discard pauses that extend beyond audio duration
    private func filterPauses(_ pauses: [PauseTimestamp], duration: TimeInterval? = nil) -> [PauseTimestamp] {
        // Filter: confidence >= 0.7, duration >= 0.3s
        var filtered = pauses.filter { pause in
            pause.confidence >= 0.7 && pause.duration >= 0.3
        }

        // Discard any pause that extends beyond audio duration
        if let audioDuration = duration {
            print("🔍 DEBUG: Filtering with duration \(audioDuration)")
            filtered = filtered.filter { pause in
                let keep = pause.endTime <= audioDuration
                if !keep {
                    print("🔍 DEBUG: Removing pause ending at \(pause.endTime) > \(audioDuration)")
                }
                return keep
            }
        }

        // Limit to max 5 pauses (take most confident ones)
        let sorted = filtered.sorted { $0.confidence > $1.confidence }
        let limited = Array(sorted.prefix(5))

        // Re-sort by time for playback order
        return limited.sorted { $0.startTime < $1.startTime }
    }


    private func cleanup() {
        // Remove time observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        // Remove boundary observer
        if let observer = boundaryObserver {
            player?.removeTimeObserver(observer)
            boundaryObserver = nil
        }

        // Remove notification observer
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)

        // Clean up player
        player?.pause()
        player = nil
        playerItem = nil
        completionHandler = nil

        // NOTE: Audio session observers are NOT removed here
        // They persist for the lifetime of the AudioPlayer instance
        // and are only removed in deinit to handle interruptions across multiple plays
    }

    // MARK: - Audio Interruption Handling

    private func handleInterruption(_ notification: Notification) {
        #if os(iOS)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Audio interruption began (phone call, CarPlay, Siri, etc.)
            print("🔴 Audio interruption began")

            // Save current state
            wasPlayingBeforeInterruption = isPlaying
            wasInPracticePauseBeforeInterruption = isPracticePause

            // If in practice pause, save remaining time
            if isPracticePause, let startTime = practicePauseStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                practicePauseRemainingDuration = max(0, duration - elapsed)
                print("💾 Saved practice pause remaining: \(practicePauseRemainingDuration)s")
            }

            // Pause everything
            if isPlaying {
                player?.pause()
                isPlaying = false
            }

            if isPracticePause {
                practicePauseTimer?.invalidate()
                practicePauseTimer = nil
            }

            isInterrupted = true

        case .ended:
            // Audio interruption ended
            print("🟢 Audio interruption ended")

            // Guard: Don't auto-resume if session was intentionally stopped
            guard isSessionActive else {
                print("⏸️ Session was stopped during interruption, not resuming")
                isInterrupted = false
                wasPlayingBeforeInterruption = false
                wasInPracticePauseBeforeInterruption = false
                practicePauseRemainingDuration = 0
                return
            }

            // Check if we should resume
            var shouldResume = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            }

            print("Should resume: \(shouldResume)")

            if shouldResume {
                // Reactivate audio session
                if reactivateAudioSession() {
                    // Restore playback state
                    if wasPlayingBeforeInterruption {
                        player?.play()
                        isPlaying = true
                        print("▶️ Resumed playback after interruption")
                    }

                    // Restore practice pause state
                    if wasInPracticePauseBeforeInterruption && practicePauseRemainingDuration > 0 {
                        isPracticePause = true
                        let remainingDuration = practicePauseRemainingDuration
                        let startTime = Date()
                        practicePauseStartTime = startTime
                        let savedCompletion = practicePauseCompletionHandler  // Capture completion

                        print("⏸️ Resuming practice pause with \(remainingDuration)s remaining")

                        practicePauseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                            // Already on main thread via RunLoop, no need for Task { @MainActor in }
                            guard let self = self else { return }
                            let elapsed = Date().timeIntervalSince(startTime)
                            self.currentProgress = self.duration - remainingDuration + elapsed

                            if elapsed >= remainingDuration {
                                self.practicePauseTimer?.invalidate()
                                self.practicePauseTimer = nil
                                self.isPracticePause = false
                                self.currentProgress = 0.0
                                self.practicePauseStartTime = nil
                                self.practicePauseCompletionHandler = nil
                                // Call the stored completion handler to advance to next verse
                                savedCompletion?()
                                print("✅ Practice pause completed after interruption, advancing to next verse")
                            }
                        }
                    }
                }
            }

            // Clear interruption state
            isInterrupted = false
            wasPlayingBeforeInterruption = false
            wasInPracticePauseBeforeInterruption = false
            practicePauseRemainingDuration = 0

        @unknown default:
            break
        }
        #endif
    }

    private func handleRouteChange(_ notification: Notification) {
        #if os(iOS)
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable:
            print("🔊 New audio device available (e.g., CarPlay connected)")
            // Continue playback - user likely wants audio to continue on new device

        case .oldDeviceUnavailable:
            print("🔇 Old audio device unavailable (e.g., headphones unplugged)")
            // Pause playback for better UX when headphones are removed
            if isPlaying {
                player?.pause()
                isPlaying = false
            }

        case .categoryChange:
            print("📱 Audio category changed")

        case .override:
            print("🔀 Audio route override")

        case .wakeFromSleep:
            print("💤 Wake from sleep")

        case .noSuitableRouteForCategory:
            print("⚠️ No suitable route for category")

        case .routeConfigurationChange:
            print("🔧 Route configuration change")

        @unknown default:
            print("❓ Unknown route change reason: \(reasonValue)")
        }
        #endif
    }

    private func handleMediaServicesReset() {
        #if os(iOS)
        print("🔄 Media services were reset - reconfiguring audio session")

        // Media services reset is rare but critical
        // The entire audio system has crashed and restarted
        // We need to completely reconfigure

        // Stop current playback
        cleanup()
        isPlaying = false
        isPracticePause = false

        // Reconfigure audio session
        setupAudioSession()

        // Set error message for user
        errorMessage = "Audio system was reset. Please restart playback."
        #endif
    }

    private func reactivateAudioSession() -> Bool {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session reactivated successfully")
            return true
        } catch {
            print("❌ Failed to reactivate audio session: \(error)")
            errorMessage = "Failed to resume audio. Please try again."
            return false
        }
        #else
        return true
        #endif
    }
}