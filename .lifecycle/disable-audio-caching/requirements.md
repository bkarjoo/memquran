# Feature Requirements: Disable Audio Caching Option

## Overview
Add a user-facing toggle in the Settings screen to enable/disable audio caching. When disabled, audio files will stream directly from the network without being saved to disk.

## Business Requirements

### Problem Statement
- The app currently caches all downloaded audio files (up to 300 MB) automatically
- Users have no control over this caching behavior
- Some users may prefer to save storage space or always get fresh audio files

### Expected Outcome
- Users can choose whether to cache audio files or stream them directly
- Setting persists across app sessions
- Clear user feedback about current caching status

## Technical Requirements

### User Interface
1. **Settings Screen Location**
   - Add toggle switch in SettingsView (Audio section, after line 148)
   - Place near other audio-related settings (e.g., reciter selection)
   - Label: "Cache Audio Files" or "Enable Audio Caching"
   - Descriptive text: "Save audio files for offline playback (uses up to 300 MB)"

2. **Toggle Behavior**
   - Default state: Enabled (ON) - maintains current behavior
   - State persisted in UserDefaults with key: "isAudioCachingEnabled"
   - Changes take effect immediately (no app restart required)

### Implementation Details

1. **AudioService Modifications**
   - Check caching preference before using AudioCacheManager
   - When caching disabled:
     - Skip cache lookup
     - Download directly to temporary file
     - Do not save to AudioCacheManager
     - Clean up temp files after playback
   - When caching enabled:
     - Use existing AudioCacheManager flow

2. **AudioCacheManager Interaction**
   - No changes to AudioCacheManager itself
   - AudioService conditionally bypasses it based on setting
   - Existing cache remains intact when toggled off (not cleared)

3. **State Management**
   - Store in UserDefaults as Bool
   - Key: "isAudioCachingEnabled"
   - Default value: true (when key doesn't exist)

## Edge Cases & Behavior

1. **Toggle While Playing**
   - Current playback continues uninterrupted
   - New setting applies to next verse/audio load

2. **Offline Behavior**
   - Caching OFF + No internet = Cannot play new verses
   - Caching ON + No internet = Can play cached verses
   - UI should handle network errors gracefully

3. **Cache Management**
   - Toggling OFF does not clear existing cache
   - User can still benefit from previously cached files
   - Consider separate "Clear Cache" button if needed (future enhancement)

4. **Performance Implications**
   - Caching OFF = More network requests
   - Caching OFF = Potentially slower verse transitions
   - Caching OFF = Higher data usage

## Testing Requirements

1. **Functional Tests**
   - Toggle saves/loads correctly from UserDefaults
   - Audio plays correctly with caching ON
   - Audio plays correctly with caching OFF
   - Network errors handled appropriately in both modes

2. **Edge Case Tests**
   - Toggle during active playback
   - Toggle with no network connection
   - App restart preserves setting
   - Default value works for fresh install

3. **Performance Tests**
   - Compare playback latency (cached vs. streamed)
   - Monitor memory usage in both modes
   - Verify temp files are cleaned up when caching OFF

## UI/UX Considerations

1. **User Communication**
   - Clear labeling about storage implications
   - Possible warning when disabling (about offline playback)
   - Visual feedback when toggle state changes

2. **Placement**
   - Group with other audio settings
   - Maintain consistent styling with other toggles
   - Ensure adequate spacing and touch targets

## Future Enhancements (Out of Scope)

1. Clear cache button
2. Cache size indicator
3. Selective caching (by surah/reciter)
4. Cache expiration policies
5. Background prefetching toggle

## Success Criteria

1. Users can successfully toggle audio caching on/off
2. Setting persists across app sessions
3. Audio playback works correctly in both modes
4. No regression in existing audio functionality
5. Clear user understanding of the feature's purpose