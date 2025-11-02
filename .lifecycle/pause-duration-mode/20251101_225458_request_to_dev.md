**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** pause-duration-mode

## Feature Request: Dual Pause Duration Modes (Learning vs Review)

### Problem Statement

Users need two different pause duration strategies for different learning stages:
- **Learning mode**: User hears verse first, then practices → pause duration = current verse duration
- **Review mode**: User recites next verse first, then hears it → pause duration = next verse duration

### Current State

Currently, the practice pause duration equals the current verse duration + 1 second buffer. There is no way to switch between learning and review modes.

### Required State Machine

#### State Variables
1. `pauseDurationMode`: Enum with two values
   - `.learning` - pause equals current verse duration (default, current behavior)
   - `.review` - pause equals next verse duration
2. `currentVerseDuration`: TimeInterval of the verse that just played
3. `nextVerseDuration`: TimeInterval of the upcoming verse (may be nil if no next verse)

#### State Transition Table

| Current Mode | User Action | Next Mode | Pause Duration Calculation |
|--------------|-------------|-----------|----------------------------|
| learning | Toggle to review | review | Use next verse duration if available, else fall back to current |
| review | Toggle to learning | learning | Use current verse duration |
| learning | Play verse | learning | pauseDuration = currentVerseDuration |
| review | Play verse | review | pauseDuration = nextVerseDuration ?? currentVerseDuration |

#### Edge Cases & Behavior

1. **No next verse exists (last verse of surah/range)**
   - If mode = `.review` and nextVerseDuration is nil → use currentVerseDuration as fallback
   - Display warning: "Review mode: last verse, using current verse duration"

2. **First verse in session**
   - Both modes work normally (next verse can be pre-fetched)

3. **Mode switching during active playback**
   - Mode change takes effect on NEXT verse only
   - Current practice pause continues with original duration
   - Display confirmation: "Mode will change on next verse"

4. **Next verse duration unavailable**
   - If in review mode and next verse duration cannot be determined → fall back to current verse duration
   - Log warning for debugging

5. **Persistence**
   - Mode selection should persist across app sessions (UserDefaults)
   - Key: "pauseDurationMode" → "learning" or "review"

### UI Requirements

**Location**: AudioMemorizationView

**Toggle Control**:
- Segmented control or picker with two options:
  - "Learning" (Listen → Practice)
  - "Review" (Recite → Verify)
- Placed near repeat mode controls
- Clearly labeled with mode description
- Shows which mode is currently active

**Status Indicator**:
- During practice pause, display which mode is active
- Example: "Practice Pause (Learning Mode)" or "Practice Pause (Review Mode)"

### Implementation Requirements

1. **Add PauseDurationMode enum** (in appropriate model file)
   ```swift
   enum PauseDurationMode: String, Codable {
       case learning  // pause = current verse duration
       case review    // pause = next verse duration
   }
   ```

2. **Update AudioPlayer or AudioMemorizationView**:
   - Add property to track selected mode
   - Modify pause duration calculation logic
   - Handle next verse duration lookup

3. **Persistence**:
   - Use @AppStorage or UserDefaults to persist mode selection
   - Default to `.learning` mode

4. **UI in AudioMemorizationView**:
   - Add mode selection control
   - Add visual indication of active mode during practice pause

### Testing Requirements

1. **Mode switching**:
   - Switch from learning to review → verify next verse duration used
   - Switch from review to learning → verify current verse duration used

2. **Edge case: last verse**:
   - Set review mode on last verse → verify fallback to current duration
   - Verify warning/message displayed

3. **Persistence**:
   - Select review mode → close app → reopen → verify review mode still selected

4. **Multi-verse playback**:
   - Play 3 verses in learning mode → verify correct durations
   - Play 3 verses in review mode → verify correct durations

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**
