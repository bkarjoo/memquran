# Requirements: Dual Pause Duration Modes (Learning vs Review)

## Problem Statement

Users need two different pause duration strategies for segment-by-segment Quran memorization practice:

- **Learning mode**: User hears a segment, then practices it → pause duration = that segment's duration
- **Review mode**: User recites the next segment from memory, then hears it → pause duration = next segment's duration

## Current Behavior

Currently, practice pause duration equals the current segment duration + 1 second buffer. There is no way to switch between learning and review modes.

## Correct Understanding: Segment-by-Segment (NOT Verse-by-Verse)

**CRITICAL**: This feature is about **segment pause durations**, not verse durations.

When pause detection is enabled:
1. Each verse audio is split into multiple segments (phrases)
2. Segments are separated by micro-pauses (e.g., 0.4s) during playback
3. After each segment plays, there's a practice pause for the user
4. The duration of this practice pause depends on the mode

**Example verse with 3 segments**:

Learning Mode Flow:
```
Play Segment 1 (3s) → micro-pause (0.4s) → Practice Pause (3s) →
Play Segment 2 (2.5s) → micro-pause (0.4s) → Practice Pause (2.5s) →
Play Segment 3 (4s) → micro-pause (0.4s) → Practice Pause (4s) → END
```

Review Mode Flow:
```
Play Segment 1 (3s) → micro-pause (0.4s) → Practice Pause (2.5s - for segment 2) →
Play Segment 2 (2.5s) → micro-pause (0.4s) → Practice Pause (4s - for segment 3) →
Play Segment 3 (4s) → micro-pause (0.4s) → END (no pause, session ends)
```

## State Machine Specification

### State Variables

1. **pauseDurationMode**: Enum with two values
   - `.learning` - practice pause = current segment duration (default)
   - `.review` - practice pause = next segment duration

2. **currentSegmentIndex**: Index of the segment that just played

3. **segments**: Array of audio segments with timing information (from pause detection)

### State Transition Table

| Mode | Segment Playing | Practice Pause Duration | User Action During Pause |
|------|----------------|------------------------|-------------------------|
| learning | Segment N | segments[N].duration | Repeat segment N that was just heard |
| review | Segment N (where N < last) | segments[N+1].duration | Recite segment N+1 from memory |
| review | Segment N (last segment) | NO PAUSE - session ends | N/A |

### Playback Flow

**Learning Mode** - Listen → Practice workflow:
```
For each segment in segments:
  1. Play segment
  2. Micro-pause (0.4s)
  3. Practice pause (duration = that segment's duration)
  4. User repeats what they heard
  5. Next segment
```

**Review Mode** - Recite → Verify workflow:
```
For each segment in segments (except last):
  1. Play segment N
  2. Micro-pause (0.4s)
  3. Practice pause (duration = segment N+1's duration)
  4. User recites segment N+1 from memory
  5. Next segment plays to verify

Last segment:
  1. Play final segment
  2. Micro-pause (0.4s)
  3. NO practice pause - session ends naturally
```

## Edge Cases & Behavior

### 1. Final Segment Handling

**Learning Mode**:
- After final segment plays → practice pause uses that segment's duration
- User repeats the final segment
- Then session ends

**Review Mode**:
- After final segment plays → NO practice pause
- Session ends immediately (after micro-pause)
- Rationale: No "next segment" to recite from memory

### 2. First Segment

Both modes work normally:
- Learning: play segment 1 → pause = segment 1 duration
- Review: play segment 1 → pause = segment 2 duration

### 3. Mode Switching During Active Playback

**Behavior**: Mode change takes effect on NEXT segment only

- Current segment's practice pause continues with original duration
- Display message: "Mode will change on next segment"

### 4. Single Segment Verse

If a verse has only 1 segment:

**Learning Mode**:
- Play segment → pause = segment duration → user repeats → end

**Review Mode**:
- Play segment → NO pause → session ends
- Rationale: No next segment exists

### 5. Persistence

- Mode selection persists across app sessions (UserDefaults/AppStorage)
- Key: `"pauseDurationMode"` → stores `"learning"` or `"review"`
- Default: `.learning`

### 6. Micro-Pauses

**UNCHANGED in both modes**:
- Micro-pauses (0.4s) still occur between segment playback and practice pauses
- These provide natural phrasing breaks during listening
- Both modes use the same micro-pause duration

## UI Requirements

### Location
AudioMemorizationView - near repeat mode controls

### Mode Selection Control

Segmented control or picker with two options:
- **"Learning"** with subtitle: "Listen → Practice"
- **"Review"** with subtitle: "Recite → Verify"

Visual indicators:
- Learning: 👂 (ear icon)
- Review: 🎤 (microphone icon)

### Status Indicator

During practice pause, display active mode:
- "Practice Pause (Learning Mode - Repeat what you heard)"
- "Practice Pause (Review Mode - Recite next segment)"

### Edge Case Messaging

When in review mode on final segment:
- Show: "Final segment - session will end after playback"

## Implementation Requirements

### 1. PauseDurationMode Enum

```swift
enum PauseDurationMode: String, Codable, Sendable {
    case learning  // pause = current segment duration
    case review    // pause = next segment duration
}
```

Location: AudioModels.swift (or appropriate model file)

### 2. AudioPlayer Modifications

**Add property**:
```swift
var pauseDurationMode: PauseDurationMode = .learning
```

**Modify segment pause calculation**:

Current logic (learning mode):
```swift
// After segment N plays
let pauseDuration = segments[currentIndex].duration + 1.0 // buffer
```

New logic (both modes):
```swift
// After segment N plays
let pauseDuration: TimeInterval

switch pauseDurationMode {
case .learning:
    // Use current segment's duration
    pauseDuration = segments[currentIndex].duration + 1.0

case .review:
    // Use next segment's duration (if exists)
    if currentIndex < segments.count - 1 {
        pauseDuration = segments[currentIndex + 1].duration + 1.0
    } else {
        // Final segment - no practice pause in review mode
        pauseDuration = 0
        skipPractice = true
    }
}
```

**Key points**:
- AudioPlayer already has segments array from pause detection
- Each segment has duration information
- Only need to change WHICH segment's duration is used
- Micro-pauses remain unchanged

### 3. AudioMemorizationView Updates

**Add state**:
```swift
@AppStorage("pauseDurationMode")
private var pauseDurationMode: PauseDurationMode = .learning
```

**Pass mode to AudioPlayer**:
```swift
audioPlayer.pauseDurationMode = pauseDurationMode
```

**UI components**:
- Mode selection segmented control
- Status indicator during practice pause
- Edge case messaging for final segment in review mode

### 4. No Verse Duration Calculation Needed

**IMPORTANT**: Unlike the incorrect implementation:
- Do NOT fetch next verse audio
- Do NOT use AVURLAsset to get verse duration
- Do NOT prefetch verse durations
- Do NOT create fetchVerseDuration() helper methods

All information needed is already available in the segments array after pause detection runs on the current verse.

## Testing Requirements

### 1. Segment-by-Segment Verification

**Learning Mode**:
- Play verse with 3 segments
- Verify pause after segment 1 = segment 1 duration
- Verify pause after segment 2 = segment 2 duration
- Verify pause after segment 3 = segment 3 duration
- Verify all micro-pauses are 0.4s

**Review Mode**:
- Play verse with 3 segments
- Verify pause after segment 1 = segment 2 duration
- Verify pause after segment 2 = segment 3 duration
- Verify NO pause after segment 3 (session ends)
- Verify all micro-pauses are 0.4s

### 2. Mode Switching

- Switch from learning to review → verify next segment uses correct duration
- Switch from review to learning → verify next segment uses correct duration
- Switch during active pause → verify current pause continues, change takes effect on next segment

### 3. Edge Cases

**Single segment verse**:
- Learning: verify pause = segment duration
- Review: verify no pause, session ends

**Final segment**:
- Learning: verify pause after final segment
- Review: verify no pause after final segment

### 4. Persistence

- Select review mode → close app → reopen → verify review mode still active
- Verify default is learning mode on first launch

### 5. UI Verification

- Segmented control displays correctly
- Status indicator shows correct mode during pause
- Edge case messages display appropriately
- Mode persists across app sessions

## Success Criteria

1. Learning mode: pause duration matches segment that just played
2. Review mode: pause duration matches next segment (if exists)
3. Review mode final segment: no pause, session ends
4. Micro-pauses unchanged in both modes (0.4s)
5. Mode selection persists across sessions
6. UI clearly indicates active mode
7. No verse-level duration calculations or prefetching
8. Build succeeds with no errors/warnings

## Why Previous Implementation Was Wrong

The first implementation incorrectly:
1. Used **verse durations** instead of **segment durations**
2. Calculated pause at verse level (one pause per verse)
3. Fetched and calculated next verse duration using AVURLAsset
4. Created prefetch methods for verse durations
5. Had fallback logic for missing next verse

This was fundamentally wrong because:
- The feature is about segment-by-segment practice, not verse-by-verse
- All needed information (segments + durations) already exists after pause detection
- No need to look ahead to other verses
- Simpler implementation using existing segment data
