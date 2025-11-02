**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** pause-duration-mode

## Feature Request: Dual Pause Duration Modes (Learning vs Review) - CORRECTED

### CRITICAL: Read Requirements First

**BEFORE implementing, read**: `.lifecycle/pause-duration-mode/requirements.md`

This document contains the complete specification including state machine, edge cases, and examples.

### What Went Wrong in Previous Implementation

The first attempt implemented this as a **verse-based** feature:
- Calculated pause duration from verse audio files using AVURLAsset
- Created methods to fetch/prefetch verse durations
- Had fallback logic for missing next verse

This was **fundamentally incorrect**. The feature is **segment-based**, not verse-based.

### Correct Understanding: Segment-Based Pause Duration

**Key Concept**: When a verse plays with pause detection enabled:
1. Verse is split into segments (phrases)
2. Each segment plays → micro-pause (0.4s) → practice pause → next segment
3. The duration of the **practice pause** depends on mode

**Learning Mode** (Listen → Practice):
- After segment N plays → practice pause = segment N's duration
- User repeats what they just heard
- Example: Seg 1 (3s) → pause (3s) → Seg 2 (2.5s) → pause (2.5s) → Seg 3 (4s) → pause (4s)

**Review Mode** (Recite → Verify):
- After segment N plays → practice pause = segment N+1's duration
- User recites the next segment from memory
- Example: Seg 1 (3s) → pause (2.5s for seg 2) → Seg 2 (2.5s) → pause (4s for seg 3) → Seg 3 (4s) → NO PAUSE (ends)

### Implementation Requirements

#### 1. Add PauseDurationMode Enum

**File**: `MemQuran/AudioModels.swift`

```swift
enum PauseDurationMode: String, Codable, Sendable {
    case learning  // pause = current segment duration
    case review    // pause = next segment duration
}
```

#### 2. Modify AudioPlayer

**File**: `MemQuran/AudioPlayer.swift`

**Add property**:
```swift
var pauseDurationMode: PauseDurationMode = .learning
```

**Find the segment pause calculation logic** (currently something like):
```swift
let pauseDuration = segmentDuration + 1.0 // learning mode
```

**Replace with**:
```swift
let pauseDuration: TimeInterval

switch pauseDurationMode {
case .learning:
    // Use current segment's duration
    pauseDuration = segments[currentSegmentIndex].duration + 1.0

case .review:
    // Use next segment's duration (if exists)
    if currentSegmentIndex < segments.count - 1 {
        // Not final segment - use next segment duration
        pauseDuration = segments[currentSegmentIndex + 1].duration + 1.0
    } else {
        // Final segment in review mode - no practice pause
        pauseDuration = 0
        // Skip practice pause and end session
        continueToNextVerse() // or whatever ends the session
        return
    }
}
```

**Key points**:
- AudioPlayer already has the segments array from pause detection
- Each segment has timing information (start/end or duration)
- Only change which segment's duration is used for the pause
- Micro-pauses (0.4s) remain unchanged in both modes

#### 3. Update AudioMemorizationView

**File**: `MemQuran/AudioMemorizationView.swift`

**Add state for mode persistence**:
```swift
@AppStorage("pauseDurationMode")
private var pauseDurationMode: PauseDurationMode = .learning
```

**Pass mode to AudioPlayer before playback**:
```swift
// Before calling audioPlayer.play()
audioPlayer.pauseDurationMode = pauseDurationMode
```

**Add UI components**:

1. **Mode Selection Control** (place near repeat mode controls):
```swift
private var pauseModeSelectionView: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Practice Mode")
            .font(.subheadline)
            .foregroundColor(.secondary)

        Picker("Pause Duration Mode", selection: $pauseDurationMode) {
            Label("Learning", systemImage: "ear")
                .tag(PauseDurationMode.learning)
            Label("Review", systemImage: "mic")
                .tag(PauseDurationMode.review)
        }
        .pickerStyle(.segmented)

        // Description of current mode
        Text(pauseDurationMode == .learning
            ? "Listen to each phrase, then repeat it"
            : "Recite next phrase from memory, then hear it"
        )
        .font(.caption)
        .foregroundColor(.secondary)
    }
}
```

2. **Status Indicator** (during practice pause):
```swift
// In your existing pause status indicator
if isPracticePause {
    VStack {
        Text("Practice Pause")
            .font(.headline)

        Text(pauseDurationMode == .learning
            ? "(Learning Mode - Repeat what you heard)"
            : "(Review Mode - Recite next phrase)"
        )
        .font(.caption)
        .foregroundColor(.secondary)
    }
}
```

3. **Edge Case Message** (for final segment in review mode):
```swift
// Show when playing final segment in review mode
if isLastSegment && pauseDurationMode == .review {
    Text("Final phrase - session will end after playback")
        .font(.caption)
        .foregroundColor(.orange)
}
```

### What NOT to Do

**DO NOT**:
- Fetch next verse audio
- Use AVURLAsset to calculate verse durations
- Create `fetchVerseDuration()` or `prefetchNextVerseDuration()` methods
- Calculate verse-level pause durations
- Have fallback logic for "missing next verse"

**WHY**: All needed information (segments and their durations) already exists in AudioPlayer after pause detection runs. This is a segment-level feature using existing data.

### Testing Requirements

After implementation:

1. **Build test**:
   - Build project → verify no errors/warnings
   - Verify code compiles

2. **Manual testing scenarios** (document in your response):
   - Play a verse with multiple segments in learning mode
   - Verify each pause duration matches the segment that just played
   - Switch to review mode
   - Verify each pause duration matches the next segment
   - Verify final segment in review mode has no pause (session ends)

### Edge Cases to Handle

1. **Single segment verse**:
   - Learning: pause after segment
   - Review: no pause, session ends

2. **Final segment**:
   - Learning: pause after final segment using its duration
   - Review: no pause, session ends immediately

3. **Mode switching during playback**:
   - Change takes effect on next segment only
   - Current segment's pause continues with original duration

4. **Persistence**:
   - Mode selection persists across app sessions
   - Default is learning mode

### Success Criteria

✅ Build succeeds without errors
✅ Enum created in AudioModels.swift
✅ AudioPlayer uses mode to select segment duration
✅ Learning mode: pause = current segment duration
✅ Review mode: pause = next segment duration (or no pause if final)
✅ Micro-pauses unchanged (0.4s)
✅ UI shows mode selection control
✅ Mode persists via @AppStorage
✅ No verse-level duration calculations

### Reference Documents

- **Complete specification**: `.lifecycle/pause-duration-mode/requirements.md`
- **Previous incorrect request**: `.lifecycle/pause-duration-mode/20251101_225458_request_to_dev.md` (for comparison)
- **Previous incorrect response**: `.lifecycle/pause-duration-mode/20251101_231335_response_from_dev.md` (what NOT to do)

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
