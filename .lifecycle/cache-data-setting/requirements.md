# Cache Data Setting Feature Requirements

## Feature Overview
Add a user-configurable setting to control whether word data is preloaded into memory at app startup or loaded on-demand when needed.

## Problem Statement
Currently, `MushafCache` has `loadAllWords()` commented out (line 19), which was previously loading all 83,668 words (3.3 MB) into memory at app startup. However, the current `getWords()` method expects words to be in cache but doesn't implement proper on-demand loading, which causes empty results when the cache is not preloaded.

Most users only need word data when:
- Bookmarking words
- Marking words as errors for revision
- Reviewing marked words

For users who just read pages or use audio playback, preloading all words is unnecessary and increases memory usage. This feature will provide a proper implementation for both cached and on-demand loading modes.

## Solution Design

### 1. New User Setting
- **Setting Name:** "Cache Quran Data"
- **Storage Key:** `isDataCachingEnabled`
- **Default Value:** `true` (maintains current behavior for existing users)
- **Location:** Settings → Performance section
- **Description:** "Load all word data at startup for faster access (uses ~3.3 MB on iPhone, ~3.5 MB on iPad)"

### 2. State Management

#### State Variables
- `isDataCachingEnabled: Bool` (UserDefaults via @AppStorage)
- `allWords: [Int: QuranWord]` dictionary in MushafCache (existing)

#### State Transitions
| Cache Setting | App Start | Word Request | Result |
|--------------|-----------|--------------|---------|
| Enabled (true) | Load all 83,668 words | Dictionary lookup | Instant (already in memory) |
| Disabled (false) | Skip loading | Load on-demand from DB | First access: 20-100ms, then cached |

### 3. Implementation Details

#### SettingsView.swift Changes
1. Add `@AppStorage` property:
   ```swift
   @AppStorage("isDataCachingEnabled") private var isDataCachingEnabled: Bool = true
   ```

2. Add UI toggle in new "Performance" section after "Audio" section:
   ```swift
   Section("Performance") {
       Toggle("Cache Quran Data", isOn: $isDataCachingEnabled)
       Text("Load all word data at startup for faster access (uses ~\(UIDevice.current.userInterfaceIdiom == .pad ? "3.5" : "3.3") MB)")
           .font(.caption)
           .foregroundColor(.secondary)
   }
   ```

#### MushafCache.swift Changes
1. In `init()` method, conditionally call `loadAllWords()` (currently commented out at line 19):
   ```swift
   private init() {
       loadQueue.async {
           // Uncomment and conditionally call loadAllWords based on user preference
           // Note: loadAllWords() is currently commented out (line 19)
           if UserDefaults.standard.bool(forKey: "isDataCachingEnabled") != false {
               self.loadAllWords()  // Uncomment this line and make conditional
           }
           self.ensurePagesLoaded(around: 2, range: 5)
           self.isLoaded = true
       }
   }
   ```

2. Modify `getWords(from:to:)` to load on-demand if not cached:
   ```swift
   public func getWords(from firstId: Int, to lastId: Int) -> [QuranWord] {
       loadQueue.sync {}

       // First, try to get all words from cache
       var result: [QuranWord] = []
       var missingIds: [Int] = []

       for id in firstId...lastId {
           if let word = allWords[id] {
               result.append(word)
           } else {
               missingIds.append(id)
           }
       }

       // If all words were cached, return immediately
       if missingIds.isEmpty {
           return result
       }

       // Load missing words from database
       if !missingIds.isEmpty {
           let words = MushafDatabase.shared.getWords(from: firstId, to: lastId)
           for word in words {
               allWords[word.id] = word
               if missingIds.contains(word.id) {
                   result.append(word)
               }
           }
       }

       // Sort result by ID to maintain order
       return result.sorted { $0.id < $1.id }
   }
   ```

### 4. Edge Cases & Behavior

#### Edge Case 1: Setting Changed While App Running
- **Scenario:** User disables caching while app is running
- **Behavior:** Existing cached words remain in memory until app restart
- **Rationale:** Clearing cache mid-session could disrupt active features

#### Edge Case 2: Setting Changed to Enabled After App Start
- **Scenario:** App started with caching disabled, user enables it
- **Behavior:** Words continue loading on-demand; full cache loads on next app start
- **Rationale:** Loading 3.3 MB mid-session could cause UI freeze

#### Edge Case 3: Partial Cache State
- **Scenario:** Caching disabled, user views pages 1-10, then enables caching and restarts
- **Behavior:** All 83,668 words loaded fresh on restart (not just missing ones)
- **Rationale:** Simpler implementation, ensures consistent state

#### Edge Case 4: Database Access Failure
- **Scenario:** On-demand loading fails to read database
- **Behavior:** Return empty array, page shows without words (graceful degradation)
- **Rationale:** Better than crashing; user can still navigate

### 5. Testing Requirements

#### Manual Test Matrix
| Test Case | Cache Setting | Action | Expected Result |
|-----------|--------------|---------|-----------------|
| T1 | Enabled | Launch app | Words preload (check memory usage) |
| T2 | Disabled | Launch app | No word preloading (lower memory) |
| T3 | Disabled | View page | Words load on first access |
| T4 | Disabled | View same page again | Words from cache (no DB query) |
| T5 | Enabled→Disabled | Change setting & navigate | Existing cache remains |
| T6 | Disabled→Enabled | Change setting & navigate | On-demand loading continues |
| T7 | Disabled | Bookmark word | Word loads and bookmarks correctly |
| T8 | Disabled | Mark word as error | Word loads and marks correctly |

#### Performance Validation
- With caching enabled: Startup memory ~3.3 MB higher
- With caching disabled: Page first view +20-100ms, subsequent views instant
- Setting change: No performance impact until app restart

### 6. Migration & Rollback

#### Migration
- New installs: Default to `true` (cache enabled)
- Existing users: Default to `true` via `Bool = true` default
- No data migration needed (setting only)

#### Rollback
- Remove setting from UI
- Remove conditional in MushafCache.init()
- Revert to always calling `loadAllWords()`

### 7. Analytics & Telemetry

#### Tracking Requirements
To understand user preferences and guide future optimization decisions, track the following:
- **Setting Usage:** Track how many users disable caching (percentage)
- **Performance Impact:** Log time taken for first word load when caching is disabled
- **Memory Savings:** Track actual memory reduction when caching is disabled

#### Implementation (Future)
```swift
// Example analytics event when setting changes
Analytics.track("cache_setting_changed", properties: [
    "enabled": isDataCachingEnabled,
    "memory_before": currentMemoryUsage,
    "device_model": UIDevice.current.model
])
```

### 8. Success Criteria
1. Setting appears in Settings → Performance
2. With caching disabled: Memory usage reduced by ~3.3 MB
3. With caching disabled: Pages still display correctly
4. No crashes or data loss when toggling setting
5. Existing users see no behavior change (default enabled)

## Implementation Order
1. Add setting to SettingsView (UI only)
2. Implement conditional loading in MushafCache.init()
3. Implement on-demand loading in getWords()
4. Test all edge cases
5. Verify memory savings with Instruments