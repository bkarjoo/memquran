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
        cleanup()

        completionHandler = completion
        isSessionActive = true  // Mark session as active when starting new playback

        // Phase 3: Unified segment system - all pauses are segments (including final)
        versePauses = filterPauses(pauses)
        nextPauseIndex = 0
        isInMicroPause = false
        isLastSegment = false
        totalPauses = versePauses.count + 1  // +1 for final segment
        currentPauseNumber = 0
        segmentStartTime = 0.0  // First segment starts at beginning

        if versePauses.count > 0 {
            print("🎯 Playing with \(versePauses.count) detected pauses + 1 final segment = \(totalPauses) total segments")
        } else {
            print("🎯 Playing as single segment (no pauses detected)")
        }

        // Reactivate audio session if it was deactivated by stop()
        #if os(iOS)
        if !reactivateAudioSession() {
            // Session reactivation failed, error message already set
            return
        }
        #endif

        // Create player item and player
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Observe playback progress
        observePlaybackProgress()

        // Observe when playback completes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        // Handle starting at specific segment
        if startAtSegment > 0 && startAtSegment <= versePauses.count {
            // Calculate start time for this segment
            // Segment N starts at the end of pause N-1
            let pause = versePauses[startAtSegment - 1]
            let startTime = pause.endTime

            // Seek to the start of this segment
            let cmTime = CMTime(seconds: startTime, preferredTimescale: 600)
            player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // Update segment tracking
            nextPauseIndex = startAtSegment
            segmentStartTime = startTime

            print("🎯 Starting at segment \(startAtSegment + 1) (time: \(startTime)s)")
        }

        // Review mode: Pause BEFORE first segment (user recites first)
        if pauseDurationMode == .review {
            // Calculate first segment duration
            let firstSegmentDuration: TimeInterval
            if versePauses.count > 0 {
                // First segment goes from start to first pause
                firstSegmentDuration = versePauses[0].startTime
            } else {
                // Single segment - use total duration
                guard let item = playerItem else { return }
                firstSegmentDuration = CMTimeGetSeconds(item.asset.duration)
            }

            print("🎵 REVIEW MODE: Starting with beep + pause (\(String(format: "%.2f", firstSegmentDuration))s) before first segment")

            // Play beep sound to cue user
            #if os(iOS)
            AudioServicesPlaySystemSound(1052) // System beep sound
            #elseif os(macOS)
            NSSound.beep()
            #endif

            // Start initial pause before playback
            isPlaying = false
            isPracticePause = true

            let startTime = Date()
            practicePauseStartTime = startTime

            // Save duration for progress bar
            let savedDuration = self.duration
            self.duration = firstSegmentDuration
            self.currentProgress = 0.0

            // Start pause timer - when it completes, start audio playback
            practicePauseTimer = Timer.scheduledTimer(withTimeInterval: firstSegmentDuration, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                print("▶️ Initial pause complete - starting audio playback")

                // End pause state
                self.isPracticePause = false
                self.practicePauseTimer?.invalidate()
                self.practicePauseTimer = nil

                // Restore original duration
                self.duration = savedDuration
                self.currentProgress = 0.0

                // NOW start the audio playback
                self.player?.play()
                self.isPlaying = true
            }

            errorMessage = nil
            return  // Don't start playback immediately
        }

        // Learning mode: Start playback immediately
        player?.play()
        isPlaying = true
        isPracticePause = false
        errorMessage = nil
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
        isSessionActive = false

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

    private func observePlaybackProgress() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // Already on main queue, no need for Task { @MainActor in }
            guard let self = self,
                  let duration = self.player?.currentItem?.duration else { return }

            let currentSeconds = CMTimeGetSeconds(time)
            let totalSeconds = CMTimeGetSeconds(duration)

            if totalSeconds.isFinite && totalSeconds > 0 {
                self.currentProgress = currentSeconds
                self.duration = totalSeconds

                // Phase 3: Check if we should trigger a micro-pause
                self.checkForMicroPause(at: currentSeconds)
            }
        }
    }

    /// Phase 3: Check if current playback time has reached a pause point
    private func checkForMicroPause(at currentTime: TimeInterval) {
        // Don't check if already in micro-pause or no pauses to process
        guard !isInMicroPause,
              nextPauseIndex < versePauses.count,
              isPlaying else { return }

        let nextPause = versePauses[nextPauseIndex]

        // Check if we've reached this pause point (within 0.2s tolerance)
        // Use the midpoint of the pause for triggering
        let pauseTriggerTime = nextPause.startTime + (nextPause.duration / 2)

        if currentTime >= pauseTriggerTime {
            // Calculate current segment duration (time since last pause or start)
            let currentSegmentDuration = currentTime - segmentStartTime

            // Calculate pause duration based on mode
            let practicePauseDuration: TimeInterval

            switch pauseDurationMode {
            case .learning:
                // Learning mode: Pause for current segment (just played, user repeats)
                practicePauseDuration = currentSegmentDuration
                print("🧪 LEARNING: Segment \(nextPauseIndex + 1) finished (\(String(format: "%.2f", currentSegmentDuration))s) → Pause for \(String(format: "%.2f", practicePauseDuration))s (user repeats)")

            case .review:
                // Review mode: Pause for NEXT segment (about to play, user recites first)
                if nextPauseIndex < versePauses.count - 1 {
                    // Not the last pause - calculate next segment duration
                    let nextSegmentStart = nextPause.endTime
                    let nextSegmentEnd = versePauses[nextPauseIndex + 1].startTime
                    practicePauseDuration = nextSegmentEnd - nextSegmentStart
                    print("🧪 REVIEW: Segment \(nextPauseIndex + 1) finished → Pause for \(String(format: "%.2f", practicePauseDuration))s (next segment duration, user recites)")
                } else {
                    // Last pause before final segment
                    practicePauseDuration = duration - nextPause.endTime
                    print("🧪 REVIEW: Segment \(nextPauseIndex + 1) finished → Pause for \(String(format: "%.2f", practicePauseDuration))s (final segment duration, user recites)")
                }
            }

            // Trigger segment pause
            currentPauseNumber = nextPauseIndex + 1  // 1-indexed for display
            startSegmentPause(at: pauseTriggerTime, segmentDuration: practicePauseDuration, isFinalSegment: false)

            // Next segment starts at the end of this pause
            segmentStartTime = nextPause.endTime
            nextPauseIndex += 1
        }
    }

    /// Phase 3: Start a segment pause (unified system for all pauses)
    /// - Parameters:
    ///   - time: Playback time when pause was triggered
    ///   - segmentDuration: Duration of the audio segment that just played
    ///   - isFinalSegment: Whether this is the final segment (advances to next verse)
    private func startSegmentPause(at time: TimeInterval, segmentDuration: TimeInterval, isFinalSegment: Bool) {
        guard let player = player else { return }

        let pauseDuration = segmentDuration
        isLastSegment = isFinalSegment

        if isFinalSegment {
            print("🏁 Final segment pause at \(String(format: "%.1f", time))s (duration: \(String(format: "%.1f", segmentDuration))s)")
        } else {
            print("⏸️ Segment pause at \(String(format: "%.1f", time))s (duration: \(String(format: "%.1f", segmentDuration))s)")
        }

        // Save current position
        pauseBeforeResuming = CMTime(seconds: time, preferredTimescale: 600)

        // Pause playback
        player.pause()
        isPlaying = false
        isInMicroPause = true
        isPracticePause = true

        // Start segment pause timer
        let startTime = Date()
        practicePauseStartTime = startTime

        // Save current duration for progress bar
        let savedDuration = self.duration
        self.duration = pauseDuration
        self.currentProgress = 0.0

        practicePauseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            self.currentProgress = elapsed

            if elapsed >= pauseDuration {
                // Segment pause finished
                self.practicePauseTimer?.invalidate()
                self.practicePauseTimer = nil
                self.isInMicroPause = false
                self.isPracticePause = false
                self.practicePauseStartTime = nil

                if self.isLastSegment {
                    // Final segment complete - advance to next verse
                    print("✅ Final segment complete - advancing to next verse")
                    self.currentPauseNumber = 0
                    let handler = self.completionHandler
                    self.completionHandler = nil
                    handler?()
                } else {
                    // Mid-verse pause - resume playback
                    self.duration = savedDuration
                    self.player?.play()
                    self.isPlaying = true
                    print("▶️ Resuming playback after segment pause")
                }
            }
        }
    }

    /// Phase 3: Filter and limit pauses for better UX
    /// - Limit to max 5 pauses per verse
    /// - Only keep pauses with good confidence and reasonable duration
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

    @objc private func audioDidFinishPlaying() {
        isPlaying = false

        // Calculate the final segment duration (from last pause end to audio end)
        let totalDuration = duration
        let finalSegmentDuration = totalDuration - segmentStartTime

        print("🏁 Audio finished. Final segment duration: \(String(format: "%.2f", finalSegmentDuration))s | Mode: \(pauseDurationMode == .learning ? "LEARNING" : "REVIEW")")

        // Both modes: practice pause after final segment
        // Learning mode: User repeats what they just heard
        // Review mode: User recites next verse (if this was last segment of current verse)
        currentPauseNumber = totalPauses  // Last segment number
        startSegmentPause(at: totalDuration, segmentDuration: finalSegmentDuration, isFinalSegment: true)
    }

    private func cleanup() {
        // Remove time observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
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