import Foundation
import AVFoundation
import Combine

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

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var practicePauseTimer: Timer?
    private var completionHandler: (() -> Void)?

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

    /// Play audio from URL
    func play(url: URL, completion: (() -> Void)? = nil) {
        cleanup()

        completionHandler = completion
        isSessionActive = true  // Mark session as active when starting new playback

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

        // Start playback
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

    /// Skip practice pause
    func skipPracticePause() {
        practicePauseTimer?.invalidate()
        practicePauseTimer = nil
        isPracticePause = false
        currentProgress = 0.0
        practicePauseStartTime = nil
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
            }
        }
    }

    @objc private func audioDidFinishPlaying() {
        isPlaying = false

        // Store the duration before cleanup
        let audioDuration = duration

        // Call completion handler which will trigger practice pause
        completionHandler?()

        // Clean up after completion
        cleanup()

        // Keep the duration for practice pause
        self.duration = audioDuration
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