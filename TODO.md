# MemQuran TODO

## URGENT - Must Fix ASAP

### Previous Issues

- [ ] Fix reciter issue - verify ar.alafasy (Mishary Alafasy) is actually being played
  - Currently using ar.alafasy in code, but user reports different reciter
  - Need to verify API response and actual audio being played

## Next Actions

- [ ] Enable CloudKit sync (requires Apple Developer account & code signing)
  - [ ] Sign up for Apple Developer account
  - [ ] Configure code signing in Xcode
  - [ ] Re-enable CloudKit entitlements
  - [ ] Test sync between devices

## Hidden Mode Navigation

### Active Work

- [ ] **Anchor System V2 - Downward Swipe Bug Fix**
  - [x] Development completed (commit 39bcfdc)
    - Fixed race condition by capturing state at gesture start
    - Applied captured values to jumpToAnchor() to prevent early returns
    - Added comprehensive console logging for debugging
  - [ ] Testing - READY FOR RE-TEST (assigned to test team)
  - [ ] Code review pending (after testing passes)

### Feature Requests

- [ ] **FEATURE**: Anchor Point Navigation in Hidden Mode
  - **Purpose**: Allow users to mark a reference point in hidden mode and quickly return to it with up swipe

  - **Selection Behavior**:
    - In hidden mode, click on any visible word or aya marker to set as anchor point
    - Only visible words/aya markers can be selected as anchor points
    - There can only be 1 anchor point at a time
    - Clicking a different visible word (not last visible word) moves the anchor point
    - The last visible word can NEVER be selected as an anchor (clicking it removes anchor if exists, does nothing if no anchor)
    - On up swipe, the last visible word automatically becomes the anchor point

  - **Visual Indicators**:
    - Normal selection: Blue rounded corner square
    - Anchor point: Red rounded corner square
    - Both indicators can coexist (blue selection moves, red anchor stays)

  - **Removal Behavior**:
    - Click on the anchor point itself to remove it
    - Click on the last visible word to remove anchor point
    - Anchor point is auto-removed if it goes out of scope (not on current or previous page)
    - Anchor point is removed if user swipes up to anchor and then swipes up again, OR swipes right to navigate before the anchor point (anchor becomes visible before navigation)

  - **Navigation Behavior**:
    - Up swipe WITH anchor point: Jump directly to anchor point (ignore aya markers on the way)
    - Up swipe WITHOUT anchor point: Normal behavior (go to previous aya marker)
    - Down/left/right swipes: Normal behavior (not affected by anchor point)
    - Blue selection indicator continues to move normally regardless of anchor point

  - **Scope & Persistence**:
    - Anchor points can be on current page or previous page only
    - Anchor points persist during the session (not just per-page)
    - Switching between visible/hidden mode does NOT delete anchor point
    - Anchor points are session-only (do NOT cloud sync)
    - Anchor point is only effective in hidden mode

  - **Implementation Plan**:
    - [ ] Add `@State var anchorPoint: WordPosition?` to ContentView (session state)
    - [ ] Add visual indicator logic to distinguish anchor point (red square) vs selection (blue square)
    - [ ] Modify word tap handler to set/remove anchor point in hidden mode (special handling for last visible word)
    - [ ] Modify up swipe logic to automatically set last visible word as anchor point before navigation
    - [ ] Implement scope validation (check if anchor on current/previous page)
    - [ ] Modify up swipe navigation to check for anchor point and jump to it
    - [ ] Add removal logic for out-of-scope and user-initiated removal
    - [ ] Add removal logic when user swipes up past anchor or swipes right before anchor
    - [ ] Test anchor point persistence across mode switches
    - [ ] Test anchor point removal in all scenarios

## Audio Memorization Mode

### Feature Requests (From Car Testing)

- [ ] **FEATURE #1**: Configurable pause duration parameters
  - Current: Pause = audio duration + 1 second buffer
  - Issue: 1 second extra is too much for some users
  - Solution: Add setting to adjust pause duration multiplier (e.g., 0.8x, 1x, 1.2x, 1.5x)
  - Also add fixed offset setting (e.g., -1s, 0s, +1s, +2s)

- [ ] **FEATURE #2**: Preview mode - pause BEFORE verse instead of after
  - Current: Play verse → Pause for practice (user recites from memory)
  - Requested: Pause first (user recites) → Play verse (user checks if correct)
  - Requires loading 2 verses ahead to know future pause duration
  - Add toggle in settings: "Practice Mode" vs "Preview Mode"
  - Preview mode use case: User wants to recite first, then hear reciter to verify

- [ ] **FEATURE #3**: Mark verse as mistake via hand swipe
  - Add swipe gesture to mark current verse as mistake
  - Should integrate with existing mistake tracking system
  - Visual feedback when mistake is marked
  - Consider which swipe direction (up/down) is most ergonomic while driving

- [ ] **FEATURE #4**: Swipe left/right for verse navigation
  - Swipe right: Go back to previous verse
  - Swipe left: Skip to next verse
  - Makes it easier to navigate without looking at buttons
  - Should work during both playback and practice pause

- [ ] **FEATURE #5**: Pause detection in audio files
  - ✅ **Phase 1 COMPLETE**: Core detection engine implemented and tested
    - Created `PauseDetectionService` with RMS amplitude analysis
    - Fixed stereo audio timing bug (2x error)
    - Tested on multiple long verses - detection is accurate
    - See `PAUSE_DETECTION_PROPOSAL.md` for full details
  - [ ] **Phase 2**: Implement persistent storage (PauseDataStore with Core Data/JSON)
  - [ ] **Phase 3**: Integrate pause detection into playback (micro-pauses during verse)
  - [ ] **Phase 4**: Add settings UI for detection parameters

