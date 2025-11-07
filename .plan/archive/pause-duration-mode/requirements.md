# Requirements: Dual Pause Duration Modes (Learning vs Review)



## Problem Statement

Users need two different pause duration strategies for segment-by-segment Quran memorization practice:

- **Learning mode**: User hears a segment, then practices it → pause duration = that segment's duration
- **Review mode**: User recites the next segment from memory, then hears it → pause duration = next segment's duration

Note: the pause calculation is identical in both modes: Pause Duration = Segment Duration. The only difference is which is played first, the pause or the segment. In learning mode the segment is played first. In review mode the pause is played first.  

## Review mode start beep

* Play a beep when audio session start to cue use to go. This is because in review mode user goes first. Where as in learning mode the recording starts first. 

## Segmentation

* The audio can also have pauses which the reciter chose to insert to catch his breath. That's why we run a pause detection algorithm to detect these reciter pauses. This algorithm divide each verse into segments. If the verse doesn't have any pauses the algorithm returns 1 segment, the entire verse.  

## Pause Calculation

* Pause duration = Segment duration, always. 

## Who goes first

* Learning mode: Recording segment is played first followed by the calculated pause. 
* Review mode: Calculated pause is played first, followed by the recording segment.
* In review mode we add a beep, so the user knows the session started and he or she should start reciting. In learning mode this is not necessary because the audio segment plays first and that in itself is a cue.



**Example verse with 3 segments**:

Learning Mode Flow:
```
Run segmentation on next verse. Let's say it has 3 segments. 
Play Segment 1 Audio (3s) → Segment 1 Practice Pause (3s) →
Play Segment 2 Audio (2.5s) → Segment 2 Practice Pause (2.5s) →
Play Segment 3 Audio (4s) → Segment 3 Practice Pause (4s) 
```

Review Mode Flow:
```
Run segmentation on next verse. Let's say it has 3 segments. 
Segment 1 Practice Pause (3s) → Play Segment 1 Audio (3s) →
Segment 2 Practice Pause (2.5s) → Play Segment 1 Audio (2.5s) →
Segment 2 Practice Pause (4s) → Play Segment 1 Audio (4s) →
```

## State Machine Specification

### State Variables

1. **pauseDurationMode**: Enum with two values
   - `.learning` - practice pause = current segment duration (default)
   - `.review` - practice pause = next segment duration

2. **currentSegmentIndex**: Index of the segment that just played

3. **segments**: Array of audio segments with timing information (from pause detection)



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
