# Pause Detection Implementation Proposal

## Problem Statement

Currently, the audio memorization mode uses a fixed approach for practice pauses:
- **Current behavior**: Pause duration = verse audio playback duration + 1 second buffer
- **Issue**: This doesn't account for the natural rhythm and internal structure of verses
- **Goal**: Detect natural pauses/silence within the reciter's audio to create more intelligent practice intervals

## Use Cases

1. **Better memorization rhythm**: Match the reciter's natural pauses to help users internalize the verse structure
2. **Verse segmentation**: Long verses often have natural breaks - detect these to allow practice of smaller chunks
3. **More natural practice flow**: Instead of one long pause after the whole verse, create multiple shorter pauses that match the reciter's pacing

## Technical Approach Options

### Option 1: Real-time Audio Analysis (AVAudioEngine)

**Pros:**
- No preprocessing required
- Works with streaming audio
- Can adapt in real-time

**Cons:**
- Complex implementation
- Higher CPU usage during playback
- May impact battery life
- More difficult to test and debug

**Implementation:**
```
AVAudioEngine → Audio Tap → Analyze amplitude → Detect silence thresholds
```

### Option 2: Pre-processing Audio Files (Recommended)

**Pros:**
- Analysis done once, cached forever
- Lower runtime overhead
- More accurate detection (can use multiple passes)
- Easier to test and debug
- Can store pause timestamps with cached audio

**Cons:**
- Requires initial processing time
- Need to store additional metadata
- Reprocessing needed if detection algorithm improves

**Implementation:**
```
Download audio → Analyze for silence → Store pause timestamps → Use during playback
```

### Option 3: Server-side Pre-analysis

**Pros:**
- No client-side processing
- Could benefit all users
- Centralized improvements

**Cons:**
- We don't control the AlQuran.cloud API
- Would need our own backend infrastructure
- Not feasible for current setup

## Recommended Solution: Option 2 (Pre-processing with Caching)

### Architecture

```
AudioCacheManager (existing)
    ↓
    ├─ Download audio file to temp cache
    └─ Return CachedVerse to AudioPlayer

NEW: PauseDataStore (persistent)
    ↓
    ├─ Store/retrieve VersePauseData by edition:surah:ayah
    ├─ Uses Core Data or JSON in Documents directory
    └─ Survives audio cache clearing

AudioPlayer (enhanced)
    ↓
    ├─ Check PauseDataStore for pause data
    ├─ If not found: analyze audio → store in PauseDataStore
    ├─ Play audio
    ├─ Monitor currentTime
    ├─ When pauseTimestamp reached → pause playback
    ├─ Start mini practice pause (2-5 seconds)
    └─ Resume playback automatically
```

### Silence Detection Algorithm

1. **Load audio into buffer** (AVAsset → AVAudioPCMBuffer)
2. **Calculate RMS (Root Mean Square) amplitude** for sliding windows
   - Window size: 100-200ms
   - Slide by: 50ms (50% overlap)
3. **Define silence threshold**
   - Dynamic threshold based on average amplitude of the verse
   - Typically: silence = RMS < (average RMS * 0.15)
4. **Detect pause regions**
   - Minimum silence duration: 300-500ms
   - Merge close pauses (< 200ms apart)
5. **Filter pause locations**
   - Ignore pauses at very beginning (first 500ms)
   - Ignore pauses at very end (last 500ms)
   - Only keep significant pauses (> 400ms duration)

### Data Model Updates

```swift
// CachedVerse remains unchanged - does NOT store pause data
struct CachedVerse {
    let surah: Int
    let ayah: Int
    let audioURL: URL
    let localFileURL: URL
    let duration: TimeInterval
    let cachedAt: Date
}

// NEW: Separate model for pause data (persisted independently)
struct VersePauseData: Codable {
    let edition: String          // e.g., "ar.alafasy" or "ar.husary.mujawwad"
    let surah: Int
    let ayah: Int
    let pauses: [PauseTimestamp]
    let detectionVersion: Int    // for future algorithm improvements
    let analyzedAt: Date

    var key: String {
        "\(edition):\(surah):\(ayah)"
    }
}

struct PauseTimestamp: Codable {
    let startTime: TimeInterval  // When silence starts
    let endTime: TimeInterval    // When silence ends
    let duration: TimeInterval   // How long the silence is
    let confidence: Float        // 0.0-1.0, how confident we are this is a real pause
}
```

### Persistence Strategy

**Key Decision: Pause data is stored separately from cached audio files**

**Why separate storage?**
- Audio files are temporary (cache can be cleared to save space)
- Pause analysis is expensive (~500ms per verse)
- Once analyzed, pause locations never change (static audio from API)
- Different reciters/editions have different pause patterns

**Storage approach:**
- Use **Core Data** (preferred) or **persistent JSON in Documents directory**
- Key format: `"{edition}:{surah}:{ayah}"` (e.g., "ar.alafasy:1:1")
- Edition identifier includes reciter AND recitation style (murattal, mujawwad, etc.)
- Survives audio cache clearing
- Can be synced via CloudKit in the future

**Lookup flow:**
```
1. User plays verse (ar.alafasy, Surah 2, Ayah 5)
2. AudioPlayer checks: PauseDataStore.getPauses(edition: "ar.alafasy", surah: 2, ayah: 5)
3. If found → use cached pause data
4. If not found → analyze during first playback, store for future use
5. Audio cache cleared? → Pause data remains intact, re-download audio only
```

### New Components

**PauseDetectionService** - Analyzes audio to detect pauses
```swift
class PauseDetectionService {
    // Main entry point
    func analyzePauses(audioURL: URL) async throws -> [PauseTimestamp]

    // Helper methods
    private func loadAudioBuffer(from: URL) throws -> AVAudioPCMBuffer
    private func calculateRMSAmplitudes(buffer: AVAudioPCMBuffer) -> [Float]
    private func detectSilenceRegions(rms: [Float], threshold: Float) -> [TimeRange]
    private func filterAndMergePauses(_ pauses: [TimeRange]) -> [PauseTimestamp]
}
```

**PauseDataStore** - Persistent storage for pause data
```swift
class PauseDataStore {
    // Retrieve pause data for a specific verse/reciter
    func getPauseData(edition: String, surah: Int, ayah: Int) -> VersePauseData?

    // Store pause data after analysis
    func savePauseData(_ data: VersePauseData)

    // Check if pause data exists without loading it
    func hasPauseData(edition: String, surah: Int, ayah: Int) -> Bool

    // Clear old pause data (e.g., if algorithm version changes)
    func clearPauseData(olderThan version: Int)

    // Storage backend (Core Data or JSON files)
    private let persistenceManager: PausePersistenceManager
}
```

### AudioPlayer Integration Options

#### A. Micro-pauses within verse (Recommended for natural flow)
- Detect 2-5 internal pauses per verse
- Each pause: 2-3 seconds
- Allows user to practice in natural chunks
- More active engagement during playback

#### B. Enhanced end-of-verse pause
- Use detected pauses to calculate better total pause duration
- Verse with many pauses = more complex = longer practice time
- Simpler implementation, maintains current UX

#### C. Hybrid approach
- Short micro-pauses during verse (1-2 seconds each)
- Longer practice pause at end (based on complexity)
- Best of both worlds

## Implementation Plan

### Phase 1: Core Detection Engine (Week 1)
1. Create `PauseDetectionService` class
2. Implement audio loading and buffer extraction
3. Implement RMS calculation algorithm
4. Implement silence detection with configurable thresholds
5. Unit tests with sample audio files

### Phase 2: Persistent Storage Implementation (Week 2)
1. Create `VersePauseData` model (Codable)
2. Create `PauseDataStore` class with Core Data or JSON persistence
3. Implement edition:surah:ayah keying system
4. Add lookup methods (getPauseData, savePauseData, hasPauseData)
5. Unit tests for persistence layer
6. NO changes to `CachedVerse` or `AudioCacheManager` needed

### Phase 3: Playback Integration (Week 3)
1. Update `AudioPlayer` to use detected pauses
2. Implement micro-pause logic during playback
3. Add visual indicators for upcoming pauses
4. Handle edge cases (no pauses detected, too many pauses)

### Phase 4: Settings & Polish (Week 4)
1. Add settings toggle: "Use intelligent pauses" vs "Simple pause"
2. Add settings for pause detection sensitivity
3. Add setting for micro-pause duration (1s, 2s, 3s)
4. Testing and refinement

## Testing Strategy

### Unit Tests
- RMS calculation accuracy
- Silence detection with known audio patterns
- Pause filtering and merging logic

### Integration Tests
- End-to-end audio analysis
- Cache storage and retrieval
- Playback with detected pauses

### Manual Testing
- Test with various reciters (different speech patterns)
- Test with short vs long verses
- Test with verses that have natural breaks vs continuous recitation
- Car testing for real-world usability

## Performance Considerations

- **Processing time**: ~500ms per verse (one-time cost, happens on first playback)
- **Storage overhead**:
  - ~100-200 bytes per verse for pause metadata
  - Stored separately in Documents directory (survives cache clearing)
  - For entire Quran (6,236 verses): ~1.2 MB total
  - Per reciter/edition (users typically use 1-2 reciters)
- **Memory usage**: Minimal at runtime (just timestamp arrays for current verse)
- **Battery impact**: Only during initial analysis, zero during subsequent playbacks
- **Network impact**: None (pause data stored locally once analyzed)

## Fallback Strategy

If pause detection fails or produces poor results:
1. Fall back to current simple pause behavior
2. Log failure for debugging
3. Allow user to disable feature in settings
4. Store empty pause array (avoid re-analyzing known problematic audio)

**Algorithm version handling:**
- Each `VersePauseData` includes `detectionVersion` field
- When algorithm improves, increment version number
- Use `PauseDataStore.clearPauseData(olderThan: newVersion)` to trigger re-analysis
- Re-analysis happens lazily (only when verse is played again)

## Future Enhancements

1. **Machine learning**: Train model to detect semantic pauses vs breath pauses
2. **User feedback**: Let users mark where they want pauses, improve algorithm
3. **Reciter profiles**: Different detection parameters for different reciters
4. **Visual waveform**: Show pause points visually in UI
5. **Custom pause placement**: Allow users to add/remove detected pauses
6. **CloudKit sync**: Sync pause data across user's devices (Core Data + CloudKit)
7. **Community sharing**: Share pause analysis results to avoid re-analyzing (opt-in)

## Open Questions

1. Should we show detected pauses visually in the UI before playback?
2. How many micro-pauses is optimal? (2? 3? 5?)
3. Should micro-pause duration be fixed or proportional to the silence duration?
4. Should we offer different modes (micro-pauses, enhanced end-pause, hybrid)?
5. Do we need different detection parameters for different reciters?

## Risk Assessment

**Low Risk:**
- Non-breaking change (can be feature-flagged)
- Fallback to current behavior if detection fails
- Only affects new audio downloads

**Medium Risk:**
- May need tuning for different reciters
- User preference varies (some may prefer simple approach)

**Mitigation:**
- Make feature opt-in initially
- Provide clear settings to customize or disable
- Gather user feedback before making default
