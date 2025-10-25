import Foundation
import AVFoundation

/// Service for detecting natural pauses/silences in audio files
/// Uses RMS (Root Mean Square) amplitude analysis to identify silence regions
public class PauseDetectionService {

    // MARK: - Configuration

    /// Configuration parameters for pause detection
    public struct DetectionConfig {
        /// Window size for RMS calculation in seconds
        let windowSize: TimeInterval

        /// Overlap between windows (0.0 to 1.0)
        let windowOverlap: Double

        /// Silence threshold as a fraction of average RMS (e.g., 0.15 = 15% of average)
        let silenceThresholdFraction: Float

        /// Minimum silence duration to be considered a pause (in seconds)
        let minimumPauseDuration: TimeInterval

        /// Maximum gap between pauses to merge them (in seconds)
        let pauseMergeThreshold: TimeInterval

        /// Time to ignore at the beginning of audio (in seconds)
        let ignoreBeginning: TimeInterval

        /// Time to ignore at the end of audio (in seconds)
        let ignoreEnd: TimeInterval

        public static let `default` = DetectionConfig(
            windowSize: 0.1,              // 100ms windows
            windowOverlap: 0.5,           // 50% overlap
            silenceThresholdFraction: 0.15,  // 15% of average RMS
            minimumPauseDuration: 0.3,    // 300ms minimum
            pauseMergeThreshold: 0.2,     // Merge pauses < 200ms apart
            ignoreBeginning: 0.5,         // Ignore first 500ms
            ignoreEnd: 0.5                // Ignore last 500ms
        )

        init(windowSize: TimeInterval = 0.1,
             windowOverlap: Double = 0.5,
             silenceThresholdFraction: Float = 0.15,
             minimumPauseDuration: TimeInterval = 0.3,
             pauseMergeThreshold: TimeInterval = 0.2,
             ignoreBeginning: TimeInterval = 0.5,
             ignoreEnd: TimeInterval = 0.5) {
            self.windowSize = windowSize
            self.windowOverlap = windowOverlap
            self.silenceThresholdFraction = silenceThresholdFraction
            self.minimumPauseDuration = minimumPauseDuration
            self.pauseMergeThreshold = pauseMergeThreshold
            self.ignoreBeginning = ignoreBeginning
            self.ignoreEnd = ignoreEnd
        }
    }

    // MARK: - Internal Types

    private struct TimeRange {
        let start: TimeInterval
        let end: TimeInterval
        var duration: TimeInterval { end - start }
    }

    // MARK: - Properties

    private let config: DetectionConfig

    // MARK: - Initialization

    public init(config: DetectionConfig = .default) {
        self.config = config
    }

    // MARK: - Public API

    // Result type that includes debug info
    public struct AnalysisResult {
        public let pauses: [PauseTimestamp]
        public let sampleRate: Double
        public let channelCount: UInt32
        public let duration: TimeInterval
    }

    /// Analyze an audio file and detect pauses/silences
    /// - Parameter audioURL: Local file URL of the audio to analyze
    /// - Returns: Analysis result with pauses and audio info
    /// - Throws: Error if audio loading or analysis fails
    public func analyzePausesWithInfo(audioURL: URL, config: DetectionConfig = .default) async throws -> AnalysisResult {
        // Load audio buffer
        let audioBuffer = try await loadAudioBuffer(from: audioURL)

        let sampleRate = audioBuffer.format.sampleRate
        let channelCount = audioBuffer.format.channelCount
        let duration = audioBuffer.duration

        // Calculate RMS amplitudes for sliding windows
        let rmsValues = calculateRMSAmplitudes(buffer: audioBuffer, config: config)

        // Detect silence regions based on threshold
        let silenceRegions = detectSilenceRegions(rmsValues: rmsValues, buffer: audioBuffer, config: config)

        // Filter and merge pauses
        let pauses = filterAndMergePauses(silenceRegions, totalDuration: duration, config: config)

        return AnalysisResult(pauses: pauses, sampleRate: sampleRate, channelCount: channelCount, duration: duration)
    }

    /// Analyze an audio file and detect pauses/silences (backward compatible)
    public func analyzePauses(audioURL: URL, config: DetectionConfig = .default) async throws -> [PauseTimestamp] {
        let result = try await analyzePausesWithInfo(audioURL: audioURL, config: config)
        return result.pauses
    }

    // MARK: - Audio Loading

    /// Load audio file into an AVAudioPCMBuffer
    private func loadAudioBuffer(from url: URL) async throws -> AVAudioPCMBuffer {
        let asset = AVAsset(url: url)

        // Get the audio track
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw PauseDetectionError.noAudioTrack
        }

        // Create audio reader
        let assetReader = try AVAssetReader(asset: asset)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let trackOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: outputSettings)
        assetReader.add(trackOutput)

        guard assetReader.startReading() else {
            throw PauseDetectionError.readerFailed
        }

        // Read all audio samples into a buffer
        var audioSamples: [Int16] = []
        var sampleRate: Double = 44100  // Default, will be updated
        var channelCount: UInt32 = 1
        var bufferCount = 0

        while assetReader.status == .reading {
            guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
                break
            }

            bufferCount += 1

            // Get format description
            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                    sampleRate = streamBasicDescription.pointee.mSampleRate
                    channelCount = streamBasicDescription.pointee.mChannelsPerFrame
                }
            }

            // Extract audio data
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = Data(count: length)

                data.withUnsafeMutableBytes { bytes in
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
                }

                // Convert to Int16 samples
                let samplesInBuffer = length / 2  // 2 bytes per Int16
                data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                    let samples = bytes.bindMemory(to: Int16.self)
                    audioSamples.append(contentsOf: samples)
                }
            }
        }

        guard assetReader.status == .completed else {
            throw PauseDetectionError.readingFailed
        }

        // Create AVAudioPCMBuffer from samples (using MONO - mix stereo to mono for analysis)
        // This fixes the 2x timing bug by converting stereo interleaved data to mono
        let frameCount = AVAudioFrameCount(audioSamples.count / Int(channelCount))

        // Use mono format for analysis (simpler and fixes timing issues)
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false)!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw PauseDetectionError.bufferCreationFailed
        }

        buffer.frameLength = frameCount

        // Copy samples to buffer - if stereo, average the channels to mono
        if let int16ChannelData = buffer.int16ChannelData {
            let pointer = int16ChannelData[0]

            if channelCount == 2 {
                // Stereo: average L and R channels
                for frame in 0..<Int(frameCount) {
                    let leftSample = Int32(audioSamples[frame * 2])
                    let rightSample = Int32(audioSamples[frame * 2 + 1])
                    let monoSample = Int16((leftSample + rightSample) / 2)
                    pointer[frame] = monoSample
                }
            } else {
                // Mono: direct copy
                for (index, sample) in audioSamples.enumerated() {
                    pointer[index] = sample
                }
            }
        }

        return buffer
    }

    // MARK: - RMS Calculation

    /// Calculate RMS (Root Mean Square) amplitude for sliding windows
    private func calculateRMSAmplitudes(buffer: AVAudioPCMBuffer, config: DetectionConfig) -> [RMSValue] {
        guard let channelData = buffer.int16ChannelData else {
            return []
        }

        let sampleRate = buffer.format.sampleRate
        let windowSampleCount = Int(config.windowSize * sampleRate)
        let stride = Int(Double(windowSampleCount) * (1.0 - config.windowOverlap))

        let samples = channelData[0]
        let totalSamples = Int(buffer.frameLength)

        var rmsValues: [RMSValue] = []

        var position = 0
        while position + windowSampleCount <= totalSamples {
            // Calculate RMS for this window
            var sumOfSquares: Double = 0.0

            for i in 0..<windowSampleCount {
                let sample = Float(samples[position + i]) / Float(Int16.max)
                sumOfSquares += Double(sample * sample)
            }

            let rms = sqrt(sumOfSquares / Double(windowSampleCount))
            let timePosition = Double(position) / sampleRate

            rmsValues.append(RMSValue(time: timePosition, amplitude: Float(rms)))

            position += stride
        }

        return rmsValues
    }

    private struct RMSValue {
        let time: TimeInterval
        let amplitude: Float
    }

    // MARK: - Silence Detection

    /// Detect silence regions based on RMS threshold
    private func detectSilenceRegions(rmsValues: [RMSValue], buffer: AVAudioPCMBuffer, config: DetectionConfig) -> [TimeRange] {
        guard !rmsValues.isEmpty else { return [] }

        // Calculate average RMS to determine dynamic threshold
        let averageRMS = rmsValues.reduce(0.0) { $0 + $1.amplitude } / Float(rmsValues.count)
        let threshold = averageRMS * config.silenceThresholdFraction

        var silenceRegions: [TimeRange] = []
        var currentSilenceStart: TimeInterval?

        for (index, rmsValue) in rmsValues.enumerated() {
            let isSilent = rmsValue.amplitude < threshold

            if isSilent && currentSilenceStart == nil {
                // Silence started
                currentSilenceStart = rmsValue.time
            } else if !isSilent && currentSilenceStart != nil {
                // Silence ended
                let silenceEnd = rmsValue.time
                silenceRegions.append(TimeRange(start: currentSilenceStart!, end: silenceEnd))
                currentSilenceStart = nil
            }
        }

        // Handle silence that continues to the end
        if let start = currentSilenceStart {
            let duration = buffer.duration
            silenceRegions.append(TimeRange(start: start, end: duration))
        }

        return silenceRegions
    }

    // MARK: - Pause Filtering and Merging

    /// Filter and merge pauses according to configuration
    private func filterAndMergePauses(_ silenceRegions: [TimeRange], totalDuration: TimeInterval, config: DetectionConfig) -> [PauseTimestamp] {
        var regions = silenceRegions

        // Filter out pauses at the beginning and end
        regions = regions.filter { region in
            region.start >= config.ignoreBeginning &&
            region.end <= (totalDuration - config.ignoreEnd)
        }

        // Filter out pauses that are too short
        regions = regions.filter { $0.duration >= config.minimumPauseDuration }

        // Merge close pauses
        var mergedRegions: [TimeRange] = []
        var currentRegion: TimeRange?

        for region in regions {
            if let current = currentRegion {
                // Check if this region should be merged with the previous one
                if region.start - current.end <= config.pauseMergeThreshold {
                    // Merge
                    currentRegion = TimeRange(start: current.start, end: region.end)
                } else {
                    // Save current and start new
                    mergedRegions.append(current)
                    currentRegion = region
                }
            } else {
                currentRegion = region
            }
        }

        // Add the last region
        if let current = currentRegion {
            mergedRegions.append(current)
        }

        // Convert to PauseTimestamp with confidence scores
        let pauses = mergedRegions.map { region in
            // Confidence based on duration (longer pauses = higher confidence)
            let confidence = min(1.0, Float(region.duration / 1.0))  // Max confidence at 1 second
            return PauseTimestamp(startTime: region.start, endTime: region.end, confidence: confidence)
        }

        return pauses
    }
}

// MARK: - Error Types

public enum PauseDetectionError: LocalizedError {
    case noAudioTrack
    case readerFailed
    case readingFailed
    case bufferCreationFailed

    public var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio track found in file"
        case .readerFailed:
            return "Failed to start audio reader"
        case .readingFailed:
            return "Audio reading failed"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        }
    }
}

// MARK: - AVAudioPCMBuffer Extension

private extension AVAudioPCMBuffer {
    var duration: TimeInterval {
        return Double(frameLength) / format.sampleRate
    }
}
