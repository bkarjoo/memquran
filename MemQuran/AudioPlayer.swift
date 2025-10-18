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

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var practicePauseTimer: Timer?
    private var completionHandler: (() -> Void)?

    // MARK: - Singleton (optional, can be instantiated per view)

    static let shared = AudioPlayer()

    // MARK: - Initialization

    init() {
        setupAudioSession()
    }

    deinit {
        // Cleanup will be handled when view disappears
        // Cannot call MainActor methods from deinit
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
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
        isPlaying = false
        isPracticePause = false
        currentProgress = 0.0
        duration = 0.0
    }

    /// Start practice pause with same duration as the audio that just played
    func startPracticePause(duration: TimeInterval, completion: @escaping () -> Void) {
        isPracticePause = true
        isPlaying = false

        // Reset progress for practice pause
        currentProgress = 0.0
        self.duration = duration

        // Create timer to track practice pause progress
        let startTime = Date()
        practicePauseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(startTime)
                self.currentProgress = elapsed

                if elapsed >= duration {
                    self.practicePauseTimer?.invalidate()
                    self.practicePauseTimer = nil
                    self.isPracticePause = false
                    self.currentProgress = 0.0
                    completion()
                }
            }
        }
    }

    /// Skip practice pause
    func skipPracticePause() {
        practicePauseTimer?.invalidate()
        practicePauseTimer = nil
        isPracticePause = false
        currentProgress = 0.0
    }

    // MARK: - Private Methods

    private func observePlaybackProgress() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
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
    }
}