# Error Bookmarks Navigation Bug - Cache Disabled Mode

## Problem Statement

**BUG:** Error bookmarks do not work when "Cache Quran Data" is disabled in Settings.

**User Experience:**
1. User opens Bookmarks view
2. User navigates to Errors tab
3. User selects an error bookmark
4. Bookmarks view closes
5. **Nothing happens** - app does not jump to the error word's page

## Root Cause Analysis

**File:** `ContentView.swift`
**Function:** `jumpToError()` (line 1306-1443)

The `jumpToError()` function searches for the error word by iterating through all 604 pages and calling:
```swift
let pageWords = MushafCache.shared.getPageWords(page)  // Line 1312, 1347
```

**Problem:** When cache is disabled, `MushafCache.getPageWords()` only returns words currently in the cache. If the cache is empty (because user toggled "Cache Quran Data" to disabled), the function returns empty results for unvisited pages, so the search loop never finds the error word and fails silently at line 1442.

**Contrast:** `jumpToBookmark()` function (line 1469) uses:
```swift
MushafDatabase.shared.getPageForWord(surah:ayah:position:)  // Line 1473
```
This queries the SQLite database directly, bypassing the cache, so it works regardless of cache state.

## Success Criteria

1. ✅ Error bookmarks work correctly when cache is **enabled** (already working)
2. ✅ Error bookmarks work correctly when cache is **disabled** (currently broken)
3. ✅ Error bookmark navigation finds the previous verse's last word (existing behavior preserved)
4. ✅ Error bookmark navigation handles edge cases:
   - Previous verse on different page (existing behavior preserved)
   - First verse of Quran (existing behavior preserved)
5. ✅ No performance regressions
6. ✅ No thread safety issues

## Technical Requirements

### Fix Strategy

Modify `jumpToError()` to query the database directly to find the page number first, rather than searching through all pages using cache.

**Recommended approach:**
1. Use `MushafDatabase.shared.getPageForWord()` to find the error word's page (like `jumpToBookmark` does)
2. Once page is found, load that page's words using `MushafCache.shared.getPageWords()` or database query
3. Find previous verse's last word on that page or previous pages
4. Navigate to the correct page and select the target word

**Alternative approach (if previous verse search is complex):**
1. Add new database query method: `getPreviousVerseLastWord(surah:ayah:)` to MushafDatabase
2. Use that to find the target word directly
3. Navigate using the result

### Edge Cases to Handle

1. **Cache disabled, unvisited pages:** Must still find error word
2. **Previous verse on different page:** Must still find previous verse's last word across pages
3. **First verse of Quran:** Should jump to error word itself (no previous verse)
4. **Word not found in database:** Should log error and fail gracefully

## Testing Requirements

**Test Scenarios:**
1. Error bookmark with cache **enabled** → should jump to previous verse's last word ✓
2. Error bookmark with cache **disabled** → should jump to previous verse's last word (currently failing)
3. Error bookmark for first verse of Quran → should jump to error word itself
4. Error bookmark where previous verse is on different page → should navigate to previous page
5. Invalid error bookmark (word doesn't exist) → should fail gracefully with log message

**Test Environment:**
- Test on device (not just simulator)
- Test with cache enabled and disabled
- Test with various error words across different pages

## Non-Requirements

- Do NOT change the behavior of regular bookmarks (they already work)
- Do NOT change the "jump to previous verse" logic (preserve existing behavior)
- Do NOT add new database tables or schema changes (use existing database methods)

## Definition of Done

- [ ] `jumpToError()` function queries database directly to find page number
- [ ] Error bookmarks work with cache disabled
- [ ] All existing error bookmark behavior preserved (previous verse logic, edge cases)
- [ ] Build succeeds with no errors
- [ ] Manual testing on device confirms fix works
- [ ] Code review approved
- [ ] No performance regressions or thread safety issues
