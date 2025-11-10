# Immediate Cache Clearing Feature Requirements

## Problem
When users toggle "Cache Quran Data" from enabled to disabled, the 3.3MB cache remains in memory until app restart. Users expect immediate memory relief and performance improvement when disabling the setting.

## User Feedback
Real device testing revealed:
- Scrolling/navigation is noticeably faster with cache disabled (less memory pressure)
- Current behavior confusing: toggle has no immediate effect
- Users must manually force quit to see benefits

## Solution
Actively clear the `allWords` dictionary when user disables caching setting.

## Implementation

### MushafCache.swift
Add public method to clear cache:
```swift
public func clearWordCache() {
    loadQueue.sync {
        allWords.removeAll()
    }
}
```

### SettingsView.swift
Clear cache immediately when setting is disabled:
```swift
Toggle("Cache Quran Data", isOn: $isDataCachingEnabled)
    .onChange(of: isDataCachingEnabled) { oldValue, newValue in
        if !newValue {  // Disabled
            MushafCache.shared.clearWordCache()
        }
    }
```

## Edge Cases

**Enable after clearing:** If user re-enables setting while app running, continue on-demand loading until next restart (don't bulk load mid-session to avoid UI freeze).

**Active word usage:** Clearing cache is safe - `getWords()` already handles on-demand loading from database.

## Success Criteria
1. Toggle to disabled → immediate memory drop (~3.3MB)
2. Scrolling performance improves immediately (no restart needed)
3. Word functionality continues working (on-demand loading)
4. No crashes or data loss

## Testing Requirements
- Memory before/after toggle (should drop ~3.3MB immediately)
- Verify words still load correctly after cache cleared
- Test rapid enable/disable toggling
- Verify no UI freezes or crashes
