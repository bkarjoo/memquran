# MemQuran TODO

## URGENT - Must Fix ASAP

### Audio Mode Bugs (Found in Car Testing)

- [x] **BUG #1**: iPhone audio view is out of screen bounds
  - Content not visible on iPhone screen
  - ✅ FIXED: Added ScrollView wrapper for iOS to allow scrolling when content exceeds screen
  - macOS keeps original VStack layout without scrolling

- [x] **BUG #2**: CarPlay audio interruption crashes/freezes audio playback
  - When CarPlay audio comes on, app audio crashes or freezes
  - Need to handle AVAudioSession interruptions properly
  - Implement audio session interruption handlers
  - ✅ FIXED: Added AVAudioSession interruption handlers

- [x] **BUG #3**: End of page error instead of auto-advancing
  - When reaching last verse on page, shows error instead of turning page
  - Currently shows: "End of page. Please select the next page."
  - Should automatically advance to next page
  - ✅ FIXED: Implemented callback-based page synchronization with @Binding
    - AudioMemorizationView now uses @Binding var currentPage to sync with parent
    - Added onPageAdvance closure that fetches new page data from parent (ContentView)
    - When last verse completes, automatically advances to next page and continues playback
    - No view recreation - preserves audio player state and session continuity
    - Handles edge case at page 604 (end of Quran)

### Previous Issues

- [ ] Fix reciter issue - verify ar.alafasy (Mishary Alafasy) is actually being played
  - Currently using ar.alafasy in code, but user reports different reciter
  - Need to verify API response and actual audio being played

- [x] Fix Arabic text not displaying in AudioMemorizationView
  - Now reads font settings from @AppStorage (fontFamily, fontSize, lineHeightMultiplier)
  - Added font validation to ensure font exists before use (with fallbacks)
  - Settings picker now shows actual system-available font names, not hardcoded list
  - Applied RTL at container level with trailing alignment for proper Arabic display
  - Verified PostScript name "ScheherazadeNew-Regular" is correct from debug logs
  - Removed corrupted Kitab-Regular.ttf file (contained HTML instead of font data)

- [x] Move History button from main toolbar to Settings
  - Removed history button from ContentView toolbar
  - Added History & Statistics navigation link in SettingsView under Statistics section

## Next Actions

- [ ] Enable CloudKit sync (requires Apple Developer account & code signing)
  - [ ] Sign up for Apple Developer account
  - [ ] Configure code signing in Xcode
  - [ ] Re-enable CloudKit entitlements
  - [ ] Test sync between devices

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
  - Detect natural pauses/silence in reciter's audio to better segment practice time
  - Instead of using fixed duration matching, analyze audio to find where reciter pauses
  - This would allow more natural practice intervals that match the reciter's rhythm
  - Could improve memorization by respecting verse internal structure
  - Implementation: Use audio analysis to detect silence/low-volume sections in audio files

### Implemented Features

- [x] Create `AudioService` class to handle API calls to AlQuran.cloud
  - [x] Implement verse audio fetching with ar.alafasy
  - [x] Handle single bitrate (128 kbps)
  - [x] Add error handling for network failures

- [x] Design `AudioMemorizationView` UI for hands-free mode
  - [x] Large play/pause button for easy tapping while driving
  - [x] Current verse display (Arabic text) - NOTE: Font issue needs fixing
  - [x] Progress indicator showing current verse on page
  - [x] Skip/previous verse controls

- [x] Implement intelligent verse caching
  - [x] Fetch next verse during practice pause
  - [x] Keep up to 10 verses in memory cache
  - [x] Allow quick access to recently practiced verses

- [x] Add practice pause system matching reciter duration
  - [x] Pause duration equals the audio duration of the verse
  - [x] Short verses get short pauses, long verses get long pauses
  - [x] Visual indicator during practice pause

- [x] Implement page-based audio progression
  - [x] Start with current page verses
  - [x] Auto-advance through all verses on page
  - [ ] Automatically turn to next page when page completes (partial - shows message)
  - [x] Continue as long as session is active

- [x] Add network connectivity check
  - [x] Alert when no internet connection
  - [x] Disable audio mode when offline
  - [ ] Auto-retry failed fetches with user feedback (partial - manual retry only)

## Completed